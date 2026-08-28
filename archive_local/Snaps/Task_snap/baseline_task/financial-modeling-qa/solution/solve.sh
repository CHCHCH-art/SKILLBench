#!/usr/bin/env bash
set -euo pipefail

DATA_PATH="${DATA_PATH:-/root/data.xlsx}"
PDF_PATH="${PDF_PATH:-/root/background.pdf}"
OUT_PATH="${OUT_PATH:-/root/answer.txt}"

[[ -r "$DATA_PATH" ]] || { echo "Missing workbook: $DATA_PATH" >&2; exit 1; }
[[ -r "$PDF_PATH" ]] || { echo "Missing background PDF: $PDF_PATH" >&2; exit 1; }
mkdir -p "$(dirname "$OUT_PATH")"

python3 - "$DATA_PATH" "$PDF_PATH" "$OUT_PATH" <<'PY'
from __future__ import annotations

import math
import re
import sys
import xml.etree.ElementTree as ET
from collections import defaultdict
from pathlib import PurePosixPath
from zipfile import ZipFile

from pypdf import PdfReader

DATA_PATH, PDF_PATH, OUT_PATH = sys.argv[1:]
MAIN = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
DOCREL = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
PKGREL = "http://schemas.openxmlformats.org/package/2006/relationships"


def norm(s: object) -> str:
    return re.sub(r"\s+", " ", str(s or "")).strip()


def pdf_text(path: str) -> str:
    reader = PdfReader(path)
    return norm(" ".join(page.extract_text() or "" for page in reader.pages))


def extract_int(pattern: str, text: str, label: str) -> int:
    m = re.search(pattern, text, re.I | re.S)
    if not m:
        raise RuntimeError(f"Cannot extract {label} from background PDF")
    return int(m.group(1).replace(",", ""))


text = pdf_text(PDF_PATH)
rules = {
    "turns_per_game": extract_int(r"Each game consists of\s+(\d+)\s+turns", text, "turns/game"),
    "rolls_per_turn": extract_int(r"roll one six-sided die\s+(\d+)\s+times", text, "rolls/turn"),
    "expected_turns": extract_int(r"contains dice rolls from\s+([\d,]+)\s+simulated turns", text, "turn count"),
    "expected_games": extract_int(r"simulated turns\s*\(([\d,]+)\s+games\)", text, "game count"),
    "only_two": extract_int(r"Only two numbers.*?\s(\d+)\s+All the numbers", text, "only-two score"),
    "all_numbers": extract_int(r"All the numbers.*?\s(\d+)\s+Ordered subset of four", text, "all-numbers score"),
    "ordered_run": extract_int(r"Ordered subset of four.*?\s(\d+)\s+For Questions", text, "ordered-run score"),
}
required_phrases = (
    "highest number rolled in the turn multiplied by the number of times",
    "sum of all six dice rolls",
    "highest number rolled multiplied by the lowest number rolled",
    "no category may be used more than once",
)
lowtext = text.casefold()
if any(p not in lowtext for p in required_phrases):
    raise RuntimeError("Background PDF does not contain the expected scoring rules")
if rules["expected_turns"] != rules["expected_games"] * rules["turns_per_game"]:
    raise RuntimeError("Background PDF has inconsistent turn/game counts")
if rules["rolls_per_turn"] != 6:
    raise RuntimeError("This scorer expects the six-roll game defined by the PDF")
if not 1 <= rules["turns_per_game"] <= 6:
    raise RuntimeError("Cannot assign six unique categories to this number of turns")
if rules["expected_games"] % 2:
    raise RuntimeError("Odd/even matching requires an even game count")


def col_index(cell_ref: str) -> int:
    m = re.match(r"([A-Z]+)", cell_ref.upper())
    if not m:
        raise ValueError(cell_ref)
    n = 0
    for ch in m.group(1):
        n = n * 26 + ord(ch) - 64
    return n


def resolve(base: str, target: str) -> str:
    if target.startswith("/"):
        return target.lstrip("/")
    return str((PurePosixPath(base).parent / target))


def shared_strings(z: ZipFile) -> list[str]:
    name = "xl/sharedStrings.xml"
    if name not in z.namelist():
        return []
    root = ET.fromstring(z.read(name))
    out = []
    for si in root.findall(f"{{{MAIN}}}si"):
        out.append("".join(t.text or "" for t in si.iter(f"{{{MAIN}}}t")))
    return out


def cell_value(cell: ET.Element, shared: list[str]):
    typ = cell.get("t")
    if typ == "inlineStr":
        return "".join(t.text or "" for t in cell.iter(f"{{{MAIN}}}t"))
    v = cell.find(f"{{{MAIN}}}v")
    if v is None or v.text is None:
        return None
    raw = v.text
    if typ == "s":
        return shared[int(raw)]
    if typ in {"str", "e"}:
        return raw
    if typ == "b":
        return raw == "1"
    try:
        x = float(raw)
        return int(x) if math.isfinite(x) and x.is_integer() else x
    except ValueError:
        return raw


with ZipFile(DATA_PATH) as z:
    shared = shared_strings(z)
    wb = ET.fromstring(z.read("xl/workbook.xml"))
    relroot = ET.fromstring(z.read("xl/_rels/workbook.xml.rels"))
    rels = {r.get("Id"): r.get("Target") for r in relroot.findall(f"{{{PKGREL}}}Relationship")}

    candidate_records: dict[int, tuple[int, tuple[int, ...]]] = {}
    conflicts: set[int] = set()
    width = 2 + rules["rolls_per_turn"]

    # The workbook may contain one or more records displaced away from the main
    # formatted table.  Treat the spreadsheet as a sparse grid and recognize
    # records by their relational invariants rather than by fixed coordinates.
    for sheet in wb.findall(f".//{{{MAIN}}}sheet"):
        rid = sheet.get(f"{{{DOCREL}}}id")
        target = rels.get(rid)
        if not target:
            continue
        sheet_path = resolve("xl/workbook.xml", target)
        root = ET.fromstring(z.read(sheet_path))
        for row in root.findall(f".//{{{MAIN}}}sheetData/{{{MAIN}}}row"):
            numeric = {}
            for c in row.findall(f"{{{MAIN}}}c"):
                value = cell_value(c, shared)
                if isinstance(value, bool):
                    continue
                if isinstance(value, (int, float)) and float(value).is_integer():
                    numeric[col_index(c.get("r", "A1"))] = int(value)
                elif isinstance(value, str) and re.fullmatch(r"[+-]?\d+", value.strip()):
                    numeric[col_index(c.get("r", "A1"))] = int(value.strip())
            if len(numeric) < width:
                continue
            lo, hi = min(numeric), max(numeric)
            for start_col in range(lo, hi - width + 2):
                window = [numeric.get(start_col + i) for i in range(width)]
                if any(v is None for v in window):
                    continue
                turn, game, *rolls = window
                if not (1 <= turn <= rules["expected_turns"]):
                    continue
                if game != (turn - 1) // rules["turns_per_game"] + 1:
                    continue
                if any(r < 1 or r > 6 for r in rolls):
                    continue
                rec = (game, tuple(rolls))
                old = candidate_records.get(turn)
                if old is None:
                    candidate_records[turn] = rec
                elif old != rec:
                    conflicts.add(turn)

if conflicts:
    raise RuntimeError(f"Conflicting turn rows found, first conflict: {min(conflicts)}")
expected_turns = rules["expected_turns"]
if set(candidate_records) != set(range(1, expected_turns + 1)):
    missing = sorted(set(range(1, expected_turns + 1)) - set(candidate_records))[:10]
    extra = sorted(set(candidate_records) - set(range(1, expected_turns + 1)))[:10]
    raise RuntimeError(f"Turn extraction failed; missing={missing}, extra={extra}")


def scores(rolls: tuple[int, ...]) -> tuple[int, ...]:
    hi, lo = max(rolls), min(rolls)
    highest_often = hi * sum(x == hi for x in rolls)
    summation = sum(rolls)
    highs_lows = hi * lo * (hi - lo)
    distinct = len(set(rolls))
    only_two = rules["only_two"] if distinct == 2 else 0
    all_numbers = rules["all_numbers"] if set(rolls) == set(range(1, 7)) else 0
    ordered = 0
    for i in range(len(rolls) - 3):
        w = rolls[i:i+4]
        if all(w[j+1] - w[j] == 1 for j in range(3)) or all(w[j+1] - w[j] == -1 for j in range(3)):
            ordered = rules["ordered_run"]
            break
    return highest_often, summation, highs_lows, only_two, all_numbers, ordered


def best_game(turn_score_vectors: list[tuple[int, ...]]) -> int:
    # State is category-bitmask -> best accumulated score.  This stays tiny
    # (at most 64 states) and works for any 1..6 turns in this game family.
    dp = {0: 0}
    for vector in turn_score_vectors:
        nxt = {}
        for mask, total in dp.items():
            for cat, sc in enumerate(vector):
                bit = 1 << cat
                if mask & bit:
                    continue
                key = mask | bit
                candidate = total + sc
                if candidate > nxt.get(key, -10**18):
                    nxt[key] = candidate
        dp = nxt
    if not dp:
        raise RuntimeError("No valid category assignment for game")
    return max(dp.values())


games: dict[int, list[tuple[int, ...]]] = defaultdict(list)
for turn in range(1, expected_turns + 1):
    game, rolls = candidate_records[turn]
    games[game].append(scores(rolls))

if set(games) != set(range(1, rules["expected_games"] + 1)):
    raise RuntimeError("Game numbering is incomplete")
for game, vectors in games.items():
    if len(vectors) != rules["turns_per_game"]:
        raise RuntimeError(f"Game {game} has {len(vectors)} turns")

game_scores = {g: best_game(games[g]) for g in sorted(games)}
answer = 0
for odd in range(1, rules["expected_games"] + 1, 2):
    a, b = game_scores[odd], game_scores[odd + 1]
    answer += (a > b) - (a < b)

with open(OUT_PATH, "w", encoding="utf-8", newline="\n") as f:
    f.write(f"{answer}\n")
PY

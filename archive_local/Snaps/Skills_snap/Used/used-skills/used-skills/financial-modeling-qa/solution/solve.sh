#!/bin/bash
set -euo pipefail

DATA_PATH="/root/data.xlsx"
PDF_PATH="/root/background.pdf"
OUT_PATH="/root/answer.txt"
WORK_DIR="$(mktemp -d /tmp/relational-game-solver.XXXXXX)"
RULES_PATH="${WORK_DIR}/rules.json"
TURNS_PATH="${WORK_DIR}/normalized_turns.csv"
TURN_SCORES_PATH="${WORK_DIR}/turn_category_scores.csv"
GAME_SCORES_PATH="${WORK_DIR}/game_scores_with_assignments.csv"

cleanup() {
    rm -rf "${WORK_DIR}"
}
trap cleanup EXIT

python3 - "${PDF_PATH}" "${RULES_PATH}" <<'PY'
import json
import re
import sys

from pypdf import PdfReader

pdf_path, rules_path = sys.argv[1:]


def pdf_text(path):
    reader = PdfReader(path)
    return re.sub(
        r"\s+",
        " ",
        " ".join(page.extract_text() or "" for page in reader.pages),
    ).strip()


def required_int(pattern, text, label):
    match = re.search(pattern, text, flags=re.IGNORECASE | re.DOTALL)
    if not match:
        raise RuntimeError(f"Could not extract {label} from the case-study PDF")
    return int(match.group(1).replace(",", ""))


text = pdf_text(pdf_path)
rules = {
    "turns_per_game": required_int(
        r"Each game consists of\s+(\d+)\s+turns", text, "turns per game"
    ),
    "rolls_per_turn": required_int(
        r"roll one six-sided die\s+(\d+)\s+times", text, "rolls per turn"
    ),
    "expected_turns": required_int(
        r"contains dice rolls from\s+([\d,]+)\s+simulated turns",
        text,
        "simulated turn count",
    ),
    "expected_games": required_int(
        r"simulated turns\s*\(([\d,]+)\s+games\)",
        text,
        "simulated game count",
    ),
    "only_two": required_int(
        r"Only two numbers.*?\s(\d+)\s+All the numbers",
        text,
        "Only two numbers score",
    ),
    "all_numbers": required_int(
        r"All the numbers.*?\s(\d+)\s+Ordered subset of four",
        text,
        "All the numbers score",
    ),
    "ordered_run": required_int(
        r"Ordered subset of four.*?\s(\d+)\s+For Questions",
        text,
        "Ordered subset score",
    ),
}

required_phrases = (
    "highest number rolled in the turn multiplied by the number of times",
    "sum of all six dice rolls",
    "highest number rolled multiplied by the lowest number rolled",
    "no category may be used more than once",
)
missing = [phrase for phrase in required_phrases if phrase.lower() not in text.lower()]
if missing:
    raise RuntimeError(f"The PDF scoring rules are incomplete: {missing}")
if rules["expected_turns"] != rules["expected_games"] * rules["turns_per_game"]:
    raise RuntimeError("The turn and game counts in the PDF are inconsistent")
if rules["rolls_per_turn"] != 6:
    raise RuntimeError("This task definition must contain exactly six rolls per turn")
if not 1 <= rules["turns_per_game"] <= 6:
    raise RuntimeError("The number of turns per game must be between one and six")
if rules["expected_games"] % 2:
    raise RuntimeError("An even number of games is required for odd/even matching")

with open(rules_path, "w", encoding="utf-8") as output:
    json.dump(rules, output, sort_keys=True)
PY

python3 - "${DATA_PATH}" "${RULES_PATH}" "${TURNS_PATH}" <<'PY'
import json
import math
import re
import sys

import numpy as np
import pandas as pd
from openpyxl import load_workbook

data_path, rules_path, turns_path = sys.argv[1:]
with open(rules_path, "r", encoding="utf-8") as source:
    rules = json.load(source)


def as_int(value):
    if value is None or isinstance(value, (bool, np.bool_)):
        return None
    if isinstance(value, (int, np.integer)):
        return int(value)
    if isinstance(value, (float, np.floating)):
        number = float(value)
        if math.isfinite(number) and number.is_integer():
            return int(number)
        return None
    if isinstance(value, str):
        stripped = value.strip()
        if re.fullmatch(r"[+-]?\d+", stripped):
            return int(stripped)
    return None


workbook = load_workbook(data_path, read_only=False, data_only=True)
sheet_frames = {
    worksheet.title: pd.DataFrame(worksheet.values)
    for worksheet in workbook.worksheets
}
workbook.close()

width = 2 + int(rules["rolls_per_turn"])
candidate_tables = []

for sheet_name, frame in sheet_frames.items():
    if frame.empty:
        continue

    cells = frame.stack(dropna=True).rename("raw_value").reset_index()
    cells.columns = ["row_index", "column_index", "raw_value"]
    cells["value"] = cells["raw_value"].map(as_int)
    cells = cells.dropna(subset=["value"])[["row_index", "column_index", "value"]]
    if cells.empty:
        continue
    cells["value"] = cells["value"].astype(np.int64)

    windows = None
    for field_offset in range(width):
        shifted = cells.copy()
        shifted["start_column"] = shifted["column_index"] - field_offset
        shifted = shifted[["row_index", "start_column", "value"]].rename(
            columns={"value": f"field_{field_offset}"}
        )
        if windows is None:
            windows = shifted
        else:
            windows = windows.merge(
                shifted,
                on=["row_index", "start_column"],
                how="inner",
                sort=False,
                validate="one_to_one",
            )

    turn = windows["field_0"]
    game = windows["field_1"]
    expected_game = ((turn - 1) // int(rules["turns_per_game"])) + 1
    valid = (turn >= 1) & (game == expected_game)
    for field_offset in range(2, width):
        valid &= windows[f"field_{field_offset}"].between(1, 6)

    selected = windows.loc[valid].copy()
    if selected.empty:
        continue
    selected.insert(0, "sheet", sheet_name)
    rename = {"field_0": "turn", "field_1": "game"}
    rename.update(
        {
            f"field_{index + 1}": f"roll_{index}"
            for index in range(1, int(rules["rolls_per_turn"]) + 1)
        }
    )
    selected = selected.rename(columns=rename)
    candidate_tables.append(
        selected[
            ["sheet", "row_index", "start_column", "turn", "game"]
            + [
                f"roll_{index}"
                for index in range(1, int(rules["rolls_per_turn"]) + 1)
            ]
        ]
    )

if not candidate_tables:
    raise RuntimeError("No valid turn records were found in the workbook")

candidates = pd.concat(candidate_tables, ignore_index=True, copy=False)
record_columns = ["game"] + [
    f"roll_{index}" for index in range(1, int(rules["rolls_per_turn"]) + 1)
]
unique_records = candidates[["turn"] + record_columns].drop_duplicates()
conflicts = unique_records.groupby("turn", sort=False).size()
conflicts = conflicts[conflicts > 1]
if not conflicts.empty:
    raise RuntimeError(f"Conflicting records for turn {int(conflicts.index[0])}")

turns = unique_records.drop_duplicates(subset=["turn"], keep="first").sort_values("turn")
expected_turns = int(rules["expected_turns"])
expected_sequence = np.arange(1, expected_turns + 1, dtype=np.int64)
actual_sequence = turns["turn"].to_numpy(dtype=np.int64, copy=False)
if len(actual_sequence) != expected_turns or not np.array_equal(actual_sequence, expected_sequence):
    actual = set(actual_sequence.tolist())
    missing = [turn for turn in range(1, expected_turns + 1) if turn not in actual][:10]
    extra = sorted(turn for turn in actual if turn > expected_turns)[:10]
    raise RuntimeError(f"Turn extraction failed: missing={missing}, extra={extra}")

counts = turns.groupby("game", sort=True)["turn"].size()
if len(counts) != int(rules["expected_games"]) or not counts.eq(
    int(rules["turns_per_game"])
).all():
    raise RuntimeError("Every game must contain the number of turns stated in the PDF")

turns.to_csv(turns_path, index=False)
PY

python3 - "${RULES_PATH}" "${TURNS_PATH}" "${TURN_SCORES_PATH}" <<'PY'
import json
import sys

import numpy as np
import pandas as pd

rules_path, turns_path, scores_path = sys.argv[1:]
with open(rules_path, "r", encoding="utf-8") as source:
    rules = json.load(source)

turns = pd.read_csv(turns_path, dtype=np.int64)
roll_columns = [f"roll_{index}" for index in range(1, int(rules["rolls_per_turn"]) + 1)]
rolls = turns[roll_columns].to_numpy(dtype=np.int64, copy=True)

highest = rolls.max(axis=1)
lowest = rolls.min(axis=1)
score_highest_frequency = highest * (rolls == highest[:, None]).sum(axis=1)
score_sum = rolls.sum(axis=1)
score_spread_product = highest * lowest * (highest - lowest)

face_presence = (rolls[:, :, None] == np.arange(1, 7, dtype=np.int64)[None, None, :]).any(axis=1)
distinct_count = face_presence.sum(axis=1)
score_only_two = np.where(distinct_count == 2, int(rules["only_two"]), 0)
score_all_numbers = np.where(distinct_count == 6, int(rules["all_numbers"]), 0)

differences = np.diff(rolls, axis=1)
run_found = np.zeros(len(turns), dtype=bool)
for start in range(int(rules["rolls_per_turn"]) - 3):
    triple = differences[:, start : start + 3]
    run_found |= np.all(triple == 1, axis=1) | np.all(triple == -1, axis=1)
score_ordered_run = np.where(run_found, int(rules["ordered_run"]), 0)

wide = turns[["turn", "game"]].copy()
wide["category_0"] = score_highest_frequency
wide["category_1"] = score_sum
wide["category_2"] = score_spread_product
wide["category_3"] = score_only_two
wide["category_4"] = score_all_numbers
wide["category_5"] = score_ordered_run

long_scores = wide.melt(
    id_vars=["turn", "game"],
    value_vars=[f"category_{index}" for index in range(6)],
    var_name="category_name",
    value_name="score",
)
long_scores["category"] = (
    long_scores["category_name"].str.removeprefix("category_").astype(np.int8)
)
long_scores["turn_slot"] = (
    (long_scores["turn"] - 1) % int(rules["turns_per_game"])
).astype(np.int8)
long_scores = long_scores[
    ["game", "turn", "turn_slot", "category", "score"]
].sort_values(["game", "turn_slot", "category"], kind="stable")

expected_rows = int(rules["expected_turns"]) * 6
if len(long_scores) != expected_rows:
    raise RuntimeError("The category-score relation has an unexpected row count")
long_scores.to_csv(scores_path, index=False)
PY

python3 - "${RULES_PATH}" "${TURN_SCORES_PATH}" "${GAME_SCORES_PATH}" <<'PY'
import json
import sys

import numpy as np
import pandas as pd

rules_path, scores_path, game_scores_path = sys.argv[1:]
with open(rules_path, "r", encoding="utf-8") as source:
    rules = json.load(source)

scores = pd.read_csv(
    scores_path,
    dtype={
        "game": np.int64,
        "turn": np.int64,
        "turn_slot": np.int8,
        "category": np.int8,
        "score": np.int64,
    },
)
turns_per_game = int(rules["turns_per_game"])

first = scores.loc[scores["turn_slot"] == 0, ["game", "category", "score"]].copy()
first = first.rename(columns={"category": "category_1", "score": "total_score"})
first["used_mask"] = np.left_shift(1, first["category_1"].to_numpy(dtype=np.int64))
frontier = first

for slot in range(1, turns_per_game):
    choice_number = slot + 1
    option = scores.loc[
        scores["turn_slot"] == slot, ["game", "category", "score"]
    ].copy()
    option = option.rename(
        columns={
            "category": f"category_{choice_number}",
            "score": f"score_{choice_number}",
        }
    )

    expanded = frontier.merge(
        option,
        on="game",
        how="inner",
        sort=False,
        validate="many_to_many",
    )
    category_values = expanded[f"category_{choice_number}"].to_numpy(dtype=np.int64)
    category_bits = np.left_shift(1, category_values)
    allowed = (expanded["used_mask"].to_numpy(dtype=np.int64) & category_bits) == 0
    expanded = expanded.loc[allowed].copy()
    expanded["used_mask"] = (
        expanded["used_mask"].to_numpy(dtype=np.int64) | category_bits[allowed]
    )
    expanded["total_score"] = (
        expanded["total_score"].to_numpy(dtype=np.int64)
        + expanded.pop(f"score_{choice_number}").to_numpy(dtype=np.int64)
    )
    frontier = expanded

if frontier.empty:
    raise RuntimeError("No valid category assignment exists")

best_rows = frontier.groupby("game", sort=True)["total_score"].idxmax()
category_columns = [f"category_{index}" for index in range(1, turns_per_game + 1)]
game_scores = frontier.loc[
    best_rows, ["game", "total_score"] + category_columns
].rename(columns={"total_score": "score"})
game_scores = game_scores.sort_values("game").reset_index(drop=True)

expected_games = int(rules["expected_games"])
expected_sequence = np.arange(1, expected_games + 1, dtype=np.int64)
if len(game_scores) != expected_games or not np.array_equal(
    game_scores["game"].to_numpy(dtype=np.int64, copy=False), expected_sequence
):
    raise RuntimeError("The assignment solver did not produce exactly one score per game")

game_scores.to_csv(game_scores_path, index=False)
PY

python3 - "${GAME_SCORES_PATH}" "${OUT_PATH}" <<'PY'
import sys

import numpy as np
import pandas as pd

game_scores_path, output_path = sys.argv[1:]
games = pd.read_csv(game_scores_path, usecols=["game", "score"], dtype=np.int64)

player_1 = games.loc[games["game"] % 2 == 1].copy()
player_1["match"] = (player_1["game"] + 1) // 2
player_1 = player_1[["match", "score"]].rename(columns={"score": "player_1_score"})

player_2 = games.loc[games["game"] % 2 == 0].copy()
player_2["match"] = player_2["game"] // 2
player_2 = player_2[["match", "score"]].rename(columns={"score": "player_2_score"})

matches = player_1.merge(
    player_2,
    on="match",
    how="inner",
    sort=True,
    validate="one_to_one",
)
if len(matches) * 2 != len(games):
    raise RuntimeError("Odd/even game pairing is incomplete")

margin = matches["player_1_score"].to_numpy() - matches["player_2_score"].to_numpy()
answer = int(np.sign(margin).sum())
with open(output_path, "w", encoding="utf-8") as output:
    output.write(f"{answer}\n")
PY

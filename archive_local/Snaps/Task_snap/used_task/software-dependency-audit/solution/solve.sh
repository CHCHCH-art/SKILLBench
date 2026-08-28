#!/bin/bash
set -Eeuo pipefail
umask 077

INPUT_LOCK="/root/package-lock.json"
OUTPUT_CSV="/root/security_audit.csv"
TRIVY_CACHE="/root/trivy-cache"
WORK_DIR="/root/.security_audit_registry_v4"
CDX_SBOM="$WORK_DIR/inventory.cdx.json"
SPDX_SBOM="$WORK_DIR/inventory.spdx.json"
STATE_DB="$WORK_DIR/audit_state.sqlite3"
REGISTRY_DIR="$WORK_DIR/offline_registry"
STAGING_DIR="$WORK_DIR/installed_staging"
AUDIT_BUNDLE="$WORK_DIR/installed_audit_bundle.tar.xz"
SCAN_ROOT="$WORK_DIR/scan_root"
TREE_REPORT="$WORK_DIR/rebuilt_tree_report.json"
DIRECT_REPORT="$WORK_DIR/direct_lock_report.json"
TRIVY_LOG="$WORK_DIR/trivy.stderr.log"

fail() {
    printf '[ERROR] %s\n' "$*" >&2
    exit 1
}

run_trivy() {
    local label="$1"
    shift
    : > "$TRIVY_LOG"
    if ! trivy "$@" 2>"$TRIVY_LOG"; then
        cat "$TRIVY_LOG" >&2 || true
        fail "$label failed"
    fi
}

command -v python3 >/dev/null 2>&1 || fail "python3 is not available"
command -v trivy >/dev/null 2>&1 || fail "trivy is not available"
[[ -f "$INPUT_LOCK" ]] || fail "input file not found: $INPUT_LOCK"
[[ -f "$TRIVY_CACHE/db/trivy.db" ]] || \
    fail "offline Trivy database not found: $TRIVY_CACHE/db/trivy.db"

rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR" "$REGISTRY_DIR" "$STAGING_DIR" "$SCAN_ROOT"

printf '[1/7] Generating two independent production inventories...\n'
run_trivy "CycloneDX inventory generation" fs "$INPUT_LOCK" \
    --format cyclonedx \
    --output "$CDX_SBOM" \
    --scanners vuln \
    --skip-db-update \
    --offline-scan \
    --cache-dir "$TRIVY_CACHE" \
    --no-progress

run_trivy "SPDX inventory generation" fs "$INPUT_LOCK" \
    --format spdx-json \
    --output "$SPDX_SBOM" \
    --scanners vuln \
    --skip-db-update \
    --offline-scan \
    --cache-dir "$TRIVY_CACHE" \
    --no-progress

[[ -s "$CDX_SBOM" ]] || fail "empty CycloneDX inventory"
[[ -s "$SPDX_SBOM" ]] || fail "empty SPDX inventory"

printf '[2/7] Normalizing inventories and materializing dependency graph closure...\n'
python3 - "$INPUT_LOCK" "$CDX_SBOM" "$SPDX_SBOM" "$STATE_DB" "$REGISTRY_DIR" <<'PY_PREPARE'
import base64
import collections
import hashlib
import io
import json
import os
import sqlite3
import sys
import tarfile
from pathlib import PurePosixPath
from urllib.parse import unquote

INPUT_LOCK, CDX_SBOM, SPDX_SBOM, STATE_DB, REGISTRY_DIR = sys.argv[1:6]


def clean(value):
    if value is None:
        return ""
    return str(value).strip()


def normalize_name(value):
    value = clean(value).rstrip("/")
    if not value:
        return ""
    if value.startswith("@"):
        if value.count("/") != 1:
            return ""
        scope, package = value.split("/", 1)
        if len(scope) < 2 or not package:
            return ""
    elif "/" in value:
        return ""
    return value


def package_name_from_path(path):
    parts = path.replace("\\", "/").split("/")
    indices = [i for i, part in enumerate(parts) if part == "node_modules"]
    if not indices:
        return ""
    i = indices[-1] + 1
    if i >= len(parts):
        return ""
    if parts[i].startswith("@"):
        if i + 1 >= len(parts):
            return ""
        return f"{parts[i]}/{parts[i + 1]}"
    return parts[i]


def parse_npm_purl(purl):
    if not isinstance(purl, str) or not purl.startswith("pkg:npm/"):
        return None
    body = purl[len("pkg:npm/"):].split("?", 1)[0].split("#", 1)[0]
    if "@" not in body:
        return None
    encoded_name, encoded_version = body.rsplit("@", 1)
    name = unquote(encoded_name)
    if name.startswith("@") and "/" in name:
        pass
    elif name.startswith("%40"):
        name = unquote(name)
    version = unquote(encoded_version)
    name = normalize_name(name)
    if not name or not version:
        return None
    return name, version, purl


def purl_from_component(component):
    if not isinstance(component, dict):
        return None
    purl = component.get("purl")
    parsed = parse_npm_purl(purl)
    if parsed:
        return parsed
    return None


def purl_from_spdx_package(package):
    if not isinstance(package, dict):
        return None
    for ref in package.get("externalRefs") or []:
        if not isinstance(ref, dict):
            continue
        locator = ref.get("referenceLocator")
        parsed = parse_npm_purl(locator)
        if parsed:
            return parsed
    return None


def dependency_names(info):
    names = set()
    if not isinstance(info, dict):
        return names
    for key in ("dependencies", "optionalDependencies"):
        value = info.get(key)
        if isinstance(value, dict):
            for name in value:
                normalized = normalize_name(name)
                if normalized:
                    names.add(normalized)
    requires = info.get("requires")
    if isinstance(requires, dict):
        for name in requires:
            normalized = normalize_name(name)
            if normalized:
                names.add(normalized)
    return names


def resolve_dependency(parent_path, dependency_name, occurrences):
    parent_path = parent_path.replace("\\", "/").strip("/")
    candidates = []
    if parent_path:
        current = parent_path
        while current:
            candidates.append(f"{current}/node_modules/{dependency_name}")
            marker = current.rfind("/node_modules/")
            if marker < 0:
                break
            current = current[:marker]
        candidates.append(f"node_modules/{dependency_name}")
    else:
        candidates.append(f"node_modules/{dependency_name}")
    for candidate in candidates:
        if candidate in occurrences:
            return candidate
    return ""


with open(INPUT_LOCK, "r", encoding="utf-8") as handle:
    lock = json.load(handle)
with open(CDX_SBOM, "r", encoding="utf-8") as handle:
    cdx = json.load(handle)
with open(SPDX_SBOM, "r", encoding="utf-8") as handle:
    spdx = json.load(handle)

cdx_components = {}
for component in cdx.get("components") or []:
    parsed = purl_from_component(component)
    if parsed:
        name, version, purl = parsed
        cdx_components[purl] = (name, version)

spdx_components = {}
for package in spdx.get("packages") or []:
    parsed = purl_from_spdx_package(package)
    if parsed:
        name, version, purl = parsed
        spdx_components[purl] = (name, version)

all_purls = sorted(set(cdx_components) | set(spdx_components))
consensus = {}
for purl in all_purls:
    values = cdx_components.get(purl) or spdx_components[purl]
    consensus[purl] = values

occurrences = {}
declared = collections.defaultdict(set)
root_dependencies = set()
packages = lock.get("packages")
if isinstance(packages, dict) and packages:
    root_info = packages.get("") if isinstance(packages.get(""), dict) else {}
    for name in dependency_names(root_info):
        root_dependencies.add(name)
    for path, info in packages.items():
        if not path or not isinstance(info, dict) or info.get("link"):
            continue
        norm_path = path.replace("\\", "/").strip("/")
        name = normalize_name(info.get("name") or package_name_from_path(norm_path))
        version = clean(info.get("version"))
        if not norm_path.startswith("node_modules/") or not name or not version:
            continue
        occurrences[norm_path] = {
            "name": name,
            "version": version,
            "dev": bool(info.get("dev", False)),
            "optional": bool(info.get("optional", False)),
            "dev_optional": bool(info.get("devOptional", False)),
        }
        declared[norm_path].update(dependency_names(info))
else:
    top = lock.get("dependencies")
    if not isinstance(top, dict):
        top = {}

    def walk(tree, parent=""):
        for raw_name, info in tree.items():
            if not isinstance(info, dict):
                continue
            name = normalize_name(raw_name)
            version = clean(info.get("version"))
            if not name or not version:
                continue
            path = f"{parent}/node_modules/{name}" if parent else f"node_modules/{name}"
            occurrences[path] = {
                "name": name,
                "version": version,
                "dev": bool(info.get("dev", False)),
                "optional": bool(info.get("optional", False)),
                "dev_optional": bool(info.get("devOptional", False)),
            }
            declared[path].update(dependency_names(info))
            if not info.get("dev", False):
                if not parent:
                    root_dependencies.add(name)
            nested = info.get("dependencies")
            if isinstance(nested, dict):
                walk(nested, path)

    walk(top)

edges = collections.defaultdict(set)
for parent_path, names in declared.items():
    for name in names:
        child = resolve_dependency(parent_path, name, occurrences)
        if child:
            edges[parent_path].add(child)

root_nodes = set()
for name in root_dependencies:
    child = resolve_dependency("", name, occurrences)
    if child:
        root_nodes.add(child)
if not root_nodes:
    for path, item in occurrences.items():
        if path.count("/node_modules/") == 0 and not item["dev"]:
            root_nodes.add(path)

closure_rows = []
impact_count = collections.Counter()
minimum_root_distance = {}
for source in sorted(occurrences):
    queue = collections.deque([(source, 0)])
    seen = {source}
    while queue:
        node, depth = queue.popleft()
        closure_rows.append((source, node, depth))
        impact_count[node] += 1
        for child in sorted(edges.get(node, ())):
            if child not in seen:
                seen.add(child)
                queue.append((child, depth + 1))

root_queue = collections.deque((node, 0) for node in sorted(root_nodes))
while root_queue:
    node, depth = root_queue.popleft()
    previous = minimum_root_distance.get(node)
    if previous is not None and previous <= depth:
        continue
    minimum_root_distance[node] = depth
    for child in sorted(edges.get(node, ())):
        root_queue.append((child, depth + 1))

if os.path.exists(STATE_DB):
    os.remove(STATE_DB)
connection = sqlite3.connect(STATE_DB)
connection.execute("PRAGMA journal_mode=WAL")
connection.execute("PRAGMA synchronous=FULL")
connection.execute("PRAGMA temp_store=MEMORY")
connection.executescript(
    """
    CREATE TABLE inventory_components (
        purl TEXT PRIMARY KEY,
        package TEXT NOT NULL,
        version TEXT NOT NULL,
        in_cyclonedx INTEGER NOT NULL,
        in_spdx INTEGER NOT NULL
    );
    CREATE TABLE lock_occurrences (
        path TEXT PRIMARY KEY,
        package TEXT NOT NULL,
        version TEXT NOT NULL,
        dev INTEGER NOT NULL,
        optional INTEGER NOT NULL,
        dev_optional INTEGER NOT NULL,
        minimum_root_distance INTEGER,
        reverse_impact_count INTEGER NOT NULL
    );
    CREATE TABLE dependency_edges (
        parent_path TEXT NOT NULL,
        child_path TEXT NOT NULL,
        PRIMARY KEY(parent_path, child_path)
    );
    CREATE TABLE transitive_closure (
        source_path TEXT NOT NULL,
        target_path TEXT NOT NULL,
        distance INTEGER NOT NULL,
        PRIMARY KEY(source_path, target_path)
    ) WITHOUT ROWID;
    CREATE INDEX idx_transitive_target ON transitive_closure(target_path);
    CREATE TABLE registry_artifacts (
        purl TEXT PRIMARY KEY,
        artifact_path TEXT NOT NULL,
        sha256 TEXT NOT NULL,
        sha512 TEXT NOT NULL,
        compressed_size INTEGER NOT NULL
    );
    CREATE TABLE reconciliation (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
    );
    """
)
connection.executemany(
    "INSERT INTO inventory_components VALUES (?, ?, ?, ?, ?)",
    [
        (
            purl,
            consensus[purl][0],
            consensus[purl][1],
            int(purl in cdx_components),
            int(purl in spdx_components),
        )
        for purl in all_purls
    ],
)
connection.executemany(
    "INSERT INTO lock_occurrences VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
    [
        (
            path,
            item["name"],
            item["version"],
            int(item["dev"]),
            int(item["optional"]),
            int(item["dev_optional"]),
            minimum_root_distance.get(path),
            impact_count[path],
        )
        for path, item in sorted(occurrences.items())
    ],
)
connection.executemany(
    "INSERT INTO dependency_edges VALUES (?, ?)",
    [(parent, child) for parent in sorted(edges) for child in sorted(edges[parent])],
)
connection.executemany(
    "INSERT INTO transitive_closure VALUES (?, ?, ?)",
    closure_rows,
)
connection.executemany(
    "INSERT INTO reconciliation VALUES (?, ?)",
    [
        ("cyclonedx_component_count", str(len(cdx_components))),
        ("spdx_component_count", str(len(spdx_components))),
        ("inventory_union_count", str(len(consensus))),
        ("lock_occurrence_count", str(len(occurrences))),
        ("dependency_edge_count", str(sum(len(v) for v in edges.values()))),
        ("transitive_closure_row_count", str(len(closure_rows))),
    ],
)
connection.commit()

os.makedirs(REGISTRY_DIR, exist_ok=True)
index_entries = []
for ordinal, purl in enumerate(all_purls, start=1):
    name, version = consensus[purl]
    artifact_id = hashlib.sha256(purl.encode("utf-8")).hexdigest()[:24]
    artifact_path = os.path.join(REGISTRY_DIR, f"{ordinal:06d}-{artifact_id}.tgz")
    package_json = {
        "name": name,
        "version": version,
        "private": True,
        "description": "Reconstructed package manifest for offline dependency audit",
        "_audit": {"purl": purl, "artifact_id": artifact_id},
    }
    package_bytes = (json.dumps(package_json, ensure_ascii=False, sort_keys=True, indent=2) + "\n").encode("utf-8")
    metadata_bytes = (json.dumps({"purl": purl, "ordinal": ordinal}, sort_keys=True) + "\n").encode("utf-8")

    with tarfile.open(artifact_path, mode="w:gz", compresslevel=9, format=tarfile.PAX_FORMAT) as archive:
        for member_name, payload in (
            ("package/package.json", package_bytes),
            ("package/.audit-metadata.json", metadata_bytes),
        ):
            info = tarfile.TarInfo(member_name)
            info.size = len(payload)
            info.mtime = 0
            info.mode = 0o644
            info.uid = 0
            info.gid = 0
            info.uname = "root"
            info.gname = "root"
            archive.addfile(info, io.BytesIO(payload))

    with open(artifact_path, "rb") as handle:
        artifact_data = handle.read()
    sha256 = hashlib.sha256(artifact_data).hexdigest()
    sha512 = hashlib.sha512(artifact_data).hexdigest()
    size = len(artifact_data)
    connection.execute(
        "INSERT INTO registry_artifacts VALUES (?, ?, ?, ?, ?)",
        (purl, artifact_path, sha256, sha512, size),
    )
    index_entries.append(
        {
            "ordinal": ordinal,
            "name": name,
            "version": version,
            "purl": purl,
            "artifact": artifact_path,
            "sha256": sha256,
            "sha512": sha512,
            "size": size,
        }
    )

with open(os.path.join(REGISTRY_DIR, "registry-index.json"), "w", encoding="utf-8") as handle:
    json.dump(index_entries, handle, ensure_ascii=False, indent=2)
    handle.write("\n")
connection.commit()
connection.close()
print(
    f"    inventories: cdx={len(cdx_components)}, spdx={len(spdx_components)}, "
    f"union={len(consensus)}; graph occurrences={len(occurrences)}, "
    f"closure rows={len(closure_rows)}; artifacts={len(index_entries)}"
)
PY_PREPARE

printf '[3/7] Installing every reconstructed npm artifact into isolated workspaces...\n'
python3 - "$STATE_DB" "$REGISTRY_DIR" "$STAGING_DIR" <<'PY_INSTALL'
import hashlib
import json
import os
import shutil
import sqlite3
import sys
import tarfile
from pathlib import PurePosixPath

STATE_DB, REGISTRY_DIR, STAGING_DIR = sys.argv[1:4]
shutil.rmtree(STAGING_DIR, ignore_errors=True)
os.makedirs(STAGING_DIR, exist_ok=True)

connection = sqlite3.connect(STATE_DB)
rows = connection.execute(
    """
    SELECT i.purl, i.package, i.version, r.artifact_path, r.sha256, r.sha512
    FROM inventory_components AS i
    JOIN registry_artifacts AS r USING (purl)
    ORDER BY i.purl
    """
).fetchall()

manifest = []
for ordinal, (purl, package, version, artifact_path, expected256, expected512) in enumerate(rows, start=1):
    with open(artifact_path, "rb") as handle:
        artifact_data = handle.read()
    if hashlib.sha256(artifact_data).hexdigest() != expected256:
        raise SystemExit(f"SHA-256 mismatch for {artifact_path}")
    if hashlib.sha512(artifact_data).hexdigest() != expected512:
        raise SystemExit(f"SHA-512 mismatch for {artifact_path}")

    workspace = os.path.join(STAGING_DIR, "workspaces", f"workspace-{ordinal:06d}")
    if package.startswith("@"):
        scope, leaf = package.split("/", 1)
        destination = os.path.join(workspace, "node_modules", scope, leaf)
    else:
        destination = os.path.join(workspace, "node_modules", package)
    os.makedirs(destination, exist_ok=True)

    with tarfile.open(artifact_path, "r:gz") as archive:
        members = archive.getmembers()
        for member in members:
            path = PurePosixPath(member.name)
            if path.is_absolute() or ".." in path.parts:
                raise SystemExit(f"unsafe archive member: {member.name}")
            if member.isfile() and member.name.startswith("package/"):
                relative = member.name[len("package/"):]
                target = os.path.join(destination, relative)
                os.makedirs(os.path.dirname(target), exist_ok=True)
                source = archive.extractfile(member)
                if source is None:
                    raise SystemExit(f"cannot extract {member.name}")
                payload = source.read()
                with open(target, "wb") as handle:
                    handle.write(payload)

    package_json_path = os.path.join(destination, "package.json")
    with open(package_json_path, "r", encoding="utf-8") as handle:
        installed = json.load(handle)
    if installed.get("name") != package or str(installed.get("version")) != version:
        raise SystemExit(f"installed manifest mismatch for {purl}")

    for current_root, _, files in os.walk(destination):
        for filename in sorted(files):
            full_path = os.path.join(current_root, filename)
            relative_path = os.path.relpath(full_path, STAGING_DIR).replace(os.sep, "/")
            with open(full_path, "rb") as handle:
                digest = hashlib.sha256(handle.read()).hexdigest()
            manifest.append({"path": relative_path, "sha256": digest})

manifest_path = os.path.join(STAGING_DIR, "AUDIT-MANIFEST.json")
with open(manifest_path, "w", encoding="utf-8") as handle:
    json.dump(manifest, handle, ensure_ascii=False, indent=2)
    handle.write("\n")
connection.execute(
    "INSERT OR REPLACE INTO reconciliation VALUES (?, ?)",
    ("installed_file_count", str(len(manifest))),
)
connection.commit()
connection.close()
print(f"    installed {len(rows)} package artifacts and hashed {len(manifest)} files")
PY_INSTALL

printf '[4/7] Creating and verifying a compressed immutable audit bundle...\n'
python3 - "$STAGING_DIR" "$AUDIT_BUNDLE" "$SCAN_ROOT" "$STATE_DB" <<'PY_BUNDLE'
import hashlib
import json
import lzma
import os
import shutil
import sqlite3
import sys
import tarfile
from pathlib import PurePosixPath

STAGING_DIR, AUDIT_BUNDLE, SCAN_ROOT, STATE_DB = sys.argv[1:5]


def normalize_tarinfo(info):
    info.uid = 0
    info.gid = 0
    info.uname = "root"
    info.gname = "root"
    info.mtime = 0
    return info

with tarfile.open(
    AUDIT_BUNDLE,
    mode="w:xz",
    preset=(9 | lzma.PRESET_EXTREME),
    format=tarfile.PAX_FORMAT,
) as archive:
    archive.add(STAGING_DIR, arcname="audit-root", recursive=True, filter=normalize_tarinfo)

with open(AUDIT_BUNDLE, "rb") as handle:
    bundle_data = handle.read()
bundle_sha256 = hashlib.sha256(bundle_data).hexdigest()

shutil.rmtree(SCAN_ROOT, ignore_errors=True)
os.makedirs(SCAN_ROOT, exist_ok=True)
with tarfile.open(AUDIT_BUNDLE, "r:xz") as archive:
    for member in archive.getmembers():
        path = PurePosixPath(member.name)
        if path.is_absolute() or ".." in path.parts:
            raise SystemExit(f"unsafe audit bundle member: {member.name}")
    archive.extractall(SCAN_ROOT)

root = os.path.join(SCAN_ROOT, "audit-root")
manifest_path = os.path.join(root, "AUDIT-MANIFEST.json")
with open(manifest_path, "r", encoding="utf-8") as handle:
    manifest = json.load(handle)
for entry in manifest:
    full_path = os.path.join(root, entry["path"])
    with open(full_path, "rb") as handle:
        actual = hashlib.sha256(handle.read()).hexdigest()
    if actual != entry["sha256"]:
        raise SystemExit(f"bundle verification failed for {entry['path']}")

connection = sqlite3.connect(STATE_DB)
connection.executemany(
    "INSERT OR REPLACE INTO reconciliation VALUES (?, ?)",
    [
        ("audit_bundle_sha256", bundle_sha256),
        ("audit_bundle_size", str(len(bundle_data))),
        ("verified_bundle_file_count", str(len(manifest))),
    ],
)
connection.commit()
connection.close()
print(f"    bundle bytes={len(bundle_data)}, verified files={len(manifest)}")
PY_BUNDLE

printf '[5/7] Scanning the reconstructed installed-package filesystem...\n'
run_trivy "reconstructed filesystem scan" fs "$SCAN_ROOT/audit-root" \
    --format json \
    --output "$TREE_REPORT" \
    --scanners vuln \
    --skip-db-update \
    --offline-scan \
    --cache-dir "$TRIVY_CACHE" \
    --no-progress
[[ -s "$TREE_REPORT" ]] || fail "empty reconstructed filesystem report"

printf '[6/7] Running an independent native lockfile control scan...\n'
run_trivy "native lockfile control scan" fs "$INPUT_LOCK" \
    --format json \
    --output "$DIRECT_REPORT" \
    --scanners vuln \
    --skip-db-update \
    --offline-scan \
    --cache-dir "$TRIVY_CACHE" \
    --no-progress
[[ -s "$DIRECT_REPORT" ]] || fail "empty native lockfile report"

printf '[7/7] Reconciling both scan paths and exporting the required CSV...\n'
python3 - "$TREE_REPORT" "$DIRECT_REPORT" "$STATE_DB" "$OUTPUT_CSV" <<'PY_EXPORT'
import csv
import json
import sqlite3
import sys

TREE_REPORT, DIRECT_REPORT, STATE_DB, OUTPUT_CSV = sys.argv[1:5]
HEADERS = [
    "Package",
    "Version",
    "CVE_ID",
    "Severity",
    "CVSS_Score",
    "Fixed_Version",
    "Title",
    "Url",
]


def scalar(value, default=""):
    if value is None:
        return default
    value = str(value)
    return value if value else default


def cvss_score(vulnerability):
    cvss = vulnerability.get("CVSS")
    if not isinstance(cvss, dict):
        return "N/A"
    for source in ("nvd", "ghsa", "redhat"):
        details = cvss.get(source)
        if isinstance(details, dict):
            score = details.get("V3Score")
            if score not in (None, ""):
                return str(score)
    return "N/A"


def parse_report(path):
    with open(path, "r", encoding="utf-8") as handle:
        report = json.load(handle)
    rows = []
    for result in report.get("Results") or []:
        for vulnerability in result.get("Vulnerabilities") or []:
            severity = scalar(vulnerability.get("Severity"), "UNKNOWN").upper()
            if severity not in {"HIGH", "CRITICAL"}:
                continue
            rows.append(
                (
                    scalar(vulnerability.get("PkgName"), "N/A"),
                    scalar(vulnerability.get("InstalledVersion"), "N/A"),
                    scalar(vulnerability.get("VulnerabilityID"), "N/A"),
                    severity,
                    cvss_score(vulnerability),
                    scalar(vulnerability.get("FixedVersion"), "N/A"),
                    scalar(vulnerability.get("Title"), "No description"),
                    scalar(vulnerability.get("PrimaryURL"), "N/A"),
                )
            )
    return rows


def multiset(rows):
    result = {}
    for row in rows:
        result[row] = result.get(row, 0) + 1
    return result


tree_rows = parse_report(TREE_REPORT)
direct_rows = parse_report(DIRECT_REPORT)
matched = multiset(tree_rows) == multiset(direct_rows)

selected_rows = tree_rows if matched else direct_rows
selected_path = "reconstructed_filesystem" if matched else "native_control_fallback"

connection = sqlite3.connect(STATE_DB)
connection.executescript(
    """
    CREATE TABLE IF NOT EXISTS reconstructed_findings (
        sequence_no INTEGER PRIMARY KEY,
        package TEXT NOT NULL,
        version TEXT NOT NULL,
        vulnerability_id TEXT NOT NULL,
        severity TEXT NOT NULL,
        cvss_score TEXT NOT NULL,
        fixed_version TEXT NOT NULL,
        title TEXT NOT NULL,
        url TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS direct_findings (
        sequence_no INTEGER PRIMARY KEY,
        package TEXT NOT NULL,
        version TEXT NOT NULL,
        vulnerability_id TEXT NOT NULL,
        severity TEXT NOT NULL,
        cvss_score TEXT NOT NULL,
        fixed_version TEXT NOT NULL,
        title TEXT NOT NULL,
        url TEXT NOT NULL
    );
    """
)
connection.executemany(
    "INSERT INTO reconstructed_findings VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
    [(index, *row) for index, row in enumerate(tree_rows, start=1)],
)
connection.executemany(
    "INSERT INTO direct_findings VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
    [(index, *row) for index, row in enumerate(direct_rows, start=1)],
)
connection.executemany(
    "INSERT OR REPLACE INTO reconciliation VALUES (?, ?)",
    [
        ("reconstructed_finding_count", str(len(tree_rows))),
        ("direct_finding_count", str(len(direct_rows))),
        ("scan_result_multisets_equal", str(matched).lower()),
        ("selected_result_path", selected_path),
    ],
)
connection.commit()
connection.close()

with open(OUTPUT_CSV, "w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle)
    writer.writerow(HEADERS)
    writer.writerows(selected_rows)

critical = sum(1 for row in selected_rows if row[3] == "CRITICAL")
high = sum(1 for row in selected_rows if row[3] == "HIGH")
print(
    f"    reconstructed={len(tree_rows)}, native={len(direct_rows)}, "
    f"equal={matched}, selected={selected_path}"
)
print(
    f"    exported {len(selected_rows)} findings "
    f"(CRITICAL={critical}, HIGH={high}) to {OUTPUT_CSV}"
)
PY_EXPORT

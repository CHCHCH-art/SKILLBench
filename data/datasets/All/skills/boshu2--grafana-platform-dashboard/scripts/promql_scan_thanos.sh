#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  promql_scan_thanos.sh --context <ctx> --dashboard-json <file.json> [options]

Options:
  --namespace <ns>        Monitoring namespace (default: openshift-monitoring)
  --selector <label=val>  Thanos pod label selector (default: app.kubernetes.io/name=thanos-query)
  --container <name>      Container to exec (default: thanos-query)
  --output <path.tsv>     Output TSV path (default: <dashboard-json>.scan.tsv)
  -h, --help              Show this help

Output TSV columns:
  panel  ref  query_status  errorType  error  expr
USAGE
}

CONTEXT=""
DASHBOARD_JSON=""
MON_NS="openshift-monitoring"
SELECTOR="app.kubernetes.io/name=thanos-query"
CONTAINER="thanos-query"
OUTPUT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --context) CONTEXT="${2:-}"; shift 2 ;;
    --dashboard-json) DASHBOARD_JSON="${2:-}"; shift 2 ;;
    --namespace) MON_NS="${2:-}"; shift 2 ;;
    --selector) SELECTOR="${2:-}"; shift 2 ;;
    --container) CONTAINER="${2:-}"; shift 2 ;;
    --output) OUTPUT="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

if [[ -z "$CONTEXT" || -z "$DASHBOARD_JSON" ]]; then
  echo "ERROR: --context and --dashboard-json are required" >&2
  usage
  exit 2
fi

if [[ ! -f "$DASHBOARD_JSON" ]]; then
  echo "ERROR: dashboard json not found: $DASHBOARD_JSON" >&2
  exit 2
fi

if [[ -z "$OUTPUT" ]]; then
  OUTPUT="${DASHBOARD_JSON}.scan.tsv"
fi

POD=$(oc --context "$CONTEXT" -n "$MON_NS" get pod -l "$SELECTOR" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
if [[ -z "$POD" ]]; then
  echo "ERROR: no thanos pod found in namespace=$MON_NS selector=$SELECTOR" >&2
  exit 1
fi

{
  echo -e "panel\tref\tquery_status\terrorType\terror\texpr"
  while IFS=$'\t' read -r panel ref expr; do
    qenc=$(jq -nr --arg v "$expr" '$v|@uri')
    resp=$(oc --context "$CONTEXT" -n "$MON_NS" exec "$POD" -c "$CONTAINER" -- sh -c "wget -qO- 'http://127.0.0.1:9090/api/v1/query?query=${qenc}'" 2>/dev/null || true)
    qstatus=$(jq -r '.status // "error"' <<<"$resp" 2>/dev/null || echo error)
    et=$(jq -r '.errorType // ""' <<<"$resp" 2>/dev/null || true)
    er=$(jq -r '.error // ""' <<<"$resp" 2>/dev/null || true)
    echo -e "${panel}\t${ref}\t${qstatus}\t${et}\t${er}\t${expr}"
  done < <(jq -r '.panels[] | select(.targets!=null) | .title as $t | .targets[] | select(has("expr")) | [$t, (.refId // "A"), .expr] | @tsv' "$DASHBOARD_JSON")
} > "$OUTPUT"

awk -F'\t' 'NR>1{t++; if($3=="success") ok++; else bad++} END{print "total="t" ok="ok+0" bad="bad+0}' "$OUTPUT"
echo "scan_tsv=$OUTPUT"

BAD=$(awk -F'\t' 'NR>1 && $3!="success"{c++} END{print c+0}' "$OUTPUT")
if [[ "$BAD" -gt 0 ]]; then
  exit 1
fi

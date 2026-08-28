#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  grafanadashboard_roundtrip.sh <command> [options]

Commands:
  export   Export GrafanaDashboard CR as YAML and dashboard JSON.
  apply    Inject dashboard JSON into live YAML and apply.

Common required options:
  --context <ctx>
  --namespace <ns>
  --name <grafanadashboard-name>

Export options:
  --out-dir <dir>    Output directory (default: /tmp/grafana-dashboard-work)

Apply options:
  --json <file>      Dashboard JSON file to apply
  --yaml <file>      Optional source YAML file; defaults to live export

Examples:
  grafanadashboard_roundtrip.sh export --context ocpeast-admin --namespace openshift-grafana-operator --name jren-release-platform-alerts-platform-health --out-dir /tmp/ocpeast-live

  grafanadashboard_roundtrip.sh apply --context ocpeast-admin --namespace openshift-grafana-operator --name jren-release-platform-alerts-platform-health --json /tmp/ocpeast-live/jren-release-platform-alerts-platform-health.json
USAGE
}

if [[ $# -lt 1 ]]; then
  usage
  exit 2
fi

CMD="$1"
shift

CONTEXT=""
NAMESPACE=""
NAME=""
OUT_DIR="/tmp/grafana-dashboard-work"
JSON_FILE=""
YAML_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --context) CONTEXT="${2:-}"; shift 2 ;;
    --namespace) NAMESPACE="${2:-}"; shift 2 ;;
    --name) NAME="${2:-}"; shift 2 ;;
    --out-dir) OUT_DIR="${2:-}"; shift 2 ;;
    --json) JSON_FILE="${2:-}"; shift 2 ;;
    --yaml) YAML_FILE="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

if [[ -z "$CONTEXT" || -z "$NAMESPACE" || -z "$NAME" ]]; then
  echo "ERROR: --context, --namespace, and --name are required" >&2
  usage
  exit 2
fi

mkdir -p "$OUT_DIR"

LIVE_YAML="$OUT_DIR/${NAME}.yaml"
LIVE_JSON="$OUT_DIR/${NAME}.json"

case "$CMD" in
  export)
    oc --context "$CONTEXT" -n "$NAMESPACE" get grafanadashboard "$NAME" -o yaml > "$LIVE_YAML"
    yq -r '.spec.json' "$LIVE_YAML" | jq '.' > "$LIVE_JSON"
    echo "yaml=$LIVE_YAML"
    echo "json=$LIVE_JSON"
    ;;

  apply)
    if [[ -z "$JSON_FILE" ]]; then
      echo "ERROR: apply requires --json" >&2
      usage
      exit 2
    fi
    if [[ ! -f "$JSON_FILE" ]]; then
      echo "ERROR: JSON file not found: $JSON_FILE" >&2
      exit 2
    fi

    if [[ -z "$YAML_FILE" ]]; then
      oc --context "$CONTEXT" -n "$NAMESPACE" get grafanadashboard "$NAME" -o yaml > "$LIVE_YAML"
      YAML_FILE="$LIVE_YAML"
    fi

    if [[ ! -f "$YAML_FILE" ]]; then
      echo "ERROR: YAML file not found: $YAML_FILE" >&2
      exit 2
    fi

    JSON_COMPACT=$(jq -c . "$JSON_FILE")
    JSON_COMPACT="$JSON_COMPACT" yq -i '.spec.json = strenv(JSON_COMPACT)' "$YAML_FILE"

    oc --context "$CONTEXT" -n "$NAMESPACE" apply -f "$YAML_FILE"
    oc --context "$CONTEXT" -n "$NAMESPACE" get grafanadashboard "$NAME" \
      -o jsonpath='{.metadata.name}{"|"}{.status.conditions[?(@.type=="DashboardSynchronized")].status}{"|"}{.status.conditions[?(@.type=="DashboardSynchronized")].reason}{"\n"}'
    ;;

  *)
    echo "ERROR: unknown command '$CMD'" >&2
    usage
    exit 2
    ;;
esac

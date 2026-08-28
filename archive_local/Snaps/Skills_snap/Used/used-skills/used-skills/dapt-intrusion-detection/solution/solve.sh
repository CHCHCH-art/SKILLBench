#!/usr/bin/env bash
set -euo pipefail

PCAP_FILE="/root/packets.pcap"
CSV_FILE="/root/network_stats.csv"
PYTHON_BIN="$(command -v python3 || true)"
MKTEMP_BIN="$(command -v mktemp || true)"
RM_BIN="$(command -v rm || true)"

[[ -n "${PYTHON_BIN}" ]] || { echo "python3 is required" >&2; exit 1; }
[[ -n "${MKTEMP_BIN}" && -n "${RM_BIN}" ]] || { echo "mktemp and rm are required" >&2; exit 1; }
[[ -r "${PCAP_FILE}" ]] || { echo "Missing input PCAP: ${PCAP_FILE}" >&2; exit 1; }
[[ -r "${CSV_FILE}" ]] || { echo "Missing CSV template: ${CSV_FILE}" >&2; exit 1; }

WORK_DIR="$("${MKTEMP_BIN}" -d /tmp/network_pdml_pipeline.XXXXXX)"
PDML_FILE="${WORK_DIR}/packets.pdml"
NDJSON_FILE="${WORK_DIR}/packets.ndjson"
cleanup() { "${RM_BIN}" -rf -- "${WORK_DIR}"; }
trap cleanup EXIT HUP INT TERM
export PCAP_FILE CSV_FILE WORK_DIR PDML_FILE NDJSON_FILE

missing_packages=()
if ! command -v tshark >/dev/null 2>&1; then
    missing_packages+=(tshark)
fi
if ! "${PYTHON_BIN}" -c 'import pandas' >/dev/null 2>&1; then
    missing_packages+=(python3-pandas)
fi
if ! "${PYTHON_BIN}" -c 'import networkx' >/dev/null 2>&1; then
    missing_packages+=(python3-networkx)
fi

if ((${#missing_packages[@]} > 0)); then
    APT_GET_BIN="$(command -v apt-get || true)"
    [[ -n "${APT_GET_BIN}" && "$(id -u)" -eq 0 ]] || {
        echo "Missing required tools and cannot install distribution packages" >&2
        exit 1
    }

    if command -v debconf-set-selections >/dev/null 2>&1; then
        printf '%s\n' 'wireshark-common wireshark-common/install-setuid boolean false' \
            | debconf-set-selections
    fi

    env DEBIAN_FRONTEND=noninteractive \
        "${APT_GET_BIN}" -o Acquire::Retries=2 \
        -o Acquire::http::Timeout=20 -o Acquire::https::Timeout=20 update
    env DEBIAN_FRONTEND=noninteractive \
        "${APT_GET_BIN}" install -y --no-install-recommends "${missing_packages[@]}"
fi

TSHARK_BIN="$(command -v tshark || true)"
[[ -n "${TSHARK_BIN}" ]] || { echo "tshark is unavailable" >&2; exit 1; }
"${PYTHON_BIN}" -c 'import pandas, networkx' >/dev/null

"${TSHARK_BIN}" -n -r "${PCAP_FILE}" -T pdml > "${PDML_FILE}"
[[ -s "${PDML_FILE}" ]] || { echo "TShark produced no PDML output" >&2; exit 1; }

"${PYTHON_BIN}" <<'PYTHON_SCRIPT'
import json
import math
import os
import xml.etree.ElementTree as ET
from pathlib import Path

import networkx as nx
import pandas as pd

PDML_FILE = Path(os.environ["PDML_FILE"])
NDJSON_FILE = Path(os.environ["NDJSON_FILE"])
OUTPUT_CSV = Path(os.environ["CSV_FILE"])


def local_name(tag):
    return tag.rsplit("}", 1)[-1]


def index_packet(packet):
    names = set()
    fields = {}
    for elem in packet.iter():
        kind = local_name(elem.tag)
        if kind == "proto":
            name = elem.get("name")
            if name:
                names.add(name)
        elif kind == "field":
            name = elem.get("name")
            if name and name not in fields:
                fields[name] = elem
    return names, fields


def field_text(fields, field_name):
    elem = fields.get(field_name)
    if elem is None:
        return None
    for key in ("show", "showname", "value"):
        value = elem.get(key)
        if value not in (None, ""):
            return value
    return None


def parse_int(value):
    if value is None:
        return None
    text = str(value).strip()
    if not text:
        return None
    try:
        return int(text, 0)
    except ValueError:
        try:
            return int(text)
        except ValueError:
            return int(text, 16)


def parse_float(value):
    if value is None:
        return None
    text = str(value).strip()
    return float(text) if text else None


def entropy(series):
    clean = series.dropna()
    if clean.empty:
        return 0.0
    counts = clean.value_counts(dropna=True)
    probabilities = counts / counts.sum()
    return round(float(-(probabilities * probabilities.map(math.log2)).sum()), 4)


def serialise(value):
    if isinstance(value, bool):
        return "true" if value else "false"
    return str(value)


packet_count = 0
context = ET.iterparse(PDML_FILE, events=("start", "end"))
_, document_root = next(context)
with NDJSON_FILE.open("w", encoding="utf-8", newline="\n") as out:
    for event, elem in context:
        if event != "end" or local_name(elem.tag) != "packet":
            continue

        names, fields = index_packet(elem)
        frame_no = parse_int(field_text(fields, "frame.number"))
        timestamp = parse_float(field_text(fields, "frame.time_epoch"))
        length = parse_int(field_text(fields, "frame.cap_len"))
        if length is None:
            length = parse_int(field_text(fields, "frame.len"))

        if frame_no is None or timestamp is None or length is None:
            raise RuntimeError(f"Incomplete mandatory fields in PDML packet {packet_count + 1}")

        flags = parse_int(field_text(fields, "tcp.flags")) or 0
        record = {
            "frame_no": frame_no,
            "ts": timestamp,
            "length": length,
            "has_ip": "ip" in names,
            "has_tcp": "tcp" in names,
            "has_udp": "udp" in names,
            "has_icmp": "icmp" in names,
            "has_arp": "arp" in names,
            "src_ip": field_text(fields, "ip.src"),
            "dst_ip": field_text(fields, "ip.dst"),
            "tcp_sport": parse_int(field_text(fields, "tcp.srcport")),
            "tcp_dport": parse_int(field_text(fields, "tcp.dstport")),
            "udp_sport": parse_int(field_text(fields, "udp.srcport")),
            "udp_dport": parse_int(field_text(fields, "udp.dstport")),
            "syn_only": bool(flags & 0x02) and not bool(flags & 0x10),
        }
        out.write(json.dumps(record, separators=(",", ":")) + "\n")
        packet_count += 1

        elem.clear()
        document_root.clear()

if packet_count == 0:
    columns = [
        "frame_no", "ts", "length", "has_ip", "has_tcp", "has_udp",
        "has_icmp", "has_arp", "src_ip", "dst_ip", "tcp_sport",
        "tcp_dport", "udp_sport", "udp_dport", "syn_only",
    ]
    df = pd.DataFrame(columns=columns)
else:
    df = pd.read_json(NDJSON_FILE, lines=True)

for column in ("has_ip", "has_tcp", "has_udp", "has_icmp", "has_arp", "syn_only"):
    if column in df:
        df[column] = df[column].fillna(False).astype(bool)

results = {}
total_packets = int(len(df))
results["total_packets"] = total_packets
results["protocol_tcp"] = int(df["has_tcp"].sum()) if total_packets else 0
results["protocol_udp"] = int(df["has_udp"].sum()) if total_packets else 0
results["protocol_icmp"] = int(df["has_icmp"].sum()) if total_packets else 0
results["protocol_arp"] = int(df["has_arp"].sum()) if total_packets else 0
results["protocol_ip_total"] = int(df["has_ip"].sum()) if total_packets else 0

if total_packets:
    results["total_bytes"] = int(df["length"].sum())
    results["avg_packet_size"] = round(float(df["length"].mean()), 2)
    results["min_packet_size"] = int(df["length"].min())
    results["max_packet_size"] = int(df["length"].max())
    first_ts = float(df["ts"].min())
    last_ts = float(df["ts"].max())
    results["duration_seconds"] = round(last_ts - first_ts, 2) if total_packets > 1 else 0.0

    buckets = ((df["ts"] - first_ts) / 60.0).astype("int64")
    packets_per_bucket = df.groupby(buckets, sort=True).size()
    results["packets_per_minute_avg"] = round(float(packets_per_bucket.mean()), 2)
    results["packets_per_minute_max"] = int(packets_per_bucket.max())
    results["packets_per_minute_min"] = int(packets_per_bucket.min())
else:
    results.update({
        "total_bytes": 0,
        "avg_packet_size": 0.0,
        "min_packet_size": 0,
        "max_packet_size": 0,
        "duration_seconds": 0.0,
        "packets_per_minute_avg": 0.0,
        "packets_per_minute_max": 0,
        "packets_per_minute_min": 0,
    })

ip_df = df[df["has_ip"]].copy() if total_packets else df.copy()
results["src_ip_entropy"] = entropy(ip_df["src_ip"])
results["dst_ip_entropy"] = entropy(ip_df["dst_ip"])

tcp_src_ports = df.loc[df["has_tcp"], "tcp_sport"] if total_packets else pd.Series(dtype="float64")
tcp_dst_ports = df.loc[df["has_tcp"], "tcp_dport"] if total_packets else pd.Series(dtype="float64")
udp_ip_mask = df["has_udp"] & df["has_ip"] if total_packets else pd.Series(dtype="bool")
udp_src_ports = df.loc[udp_ip_mask, "udp_sport"] if total_packets else pd.Series(dtype="float64")
udp_dst_ports = df.loc[udp_ip_mask, "udp_dport"] if total_packets else pd.Series(dtype="float64")
src_ports = pd.concat([tcp_src_ports, udp_src_ports], ignore_index=True).dropna()
dst_ports = pd.concat([tcp_dst_ports, udp_dst_ports], ignore_index=True).dropna()
results["src_port_entropy"] = entropy(src_ports)
results["dst_port_entropy"] = entropy(dst_ports)
results["unique_src_ports"] = int(src_ports.nunique())
results["unique_dst_ports"] = int(dst_ports.nunique())

valid_ip_df = ip_df.dropna(subset=["src_ip", "dst_ip"])
edges_df = valid_ip_df[["src_ip", "dst_ip"]].drop_duplicates()
all_nodes = set(ip_df["src_ip"].dropna()) | set(ip_df["dst_ip"].dropna())
graph = nx.DiGraph()
graph.add_nodes_from(all_nodes)
graph.add_edges_from(edges_df.itertuples(index=False, name=None))
num_nodes = int(graph.number_of_nodes())
num_edges = int(graph.number_of_edges())
results["num_nodes"] = num_nodes
results["num_edges"] = num_edges
results["network_density"] = round(num_edges / (num_nodes * (num_nodes - 1)), 6) if num_nodes >= 2 else 0.0
results["max_outdegree"] = max((degree for _, degree in graph.out_degree()), default=0)
results["max_indegree"] = max((degree for _, degree in graph.in_degree()), default=0)

if total_packets > 1:
    ordered = df.sort_values(["ts", "frame_no"], kind="mergesort")
    iats = ordered["ts"].diff().dropna()
    iat_mean = float(iats.mean())
    iat_variance = float(iats.var(ddof=0))
    iat_std = math.sqrt(max(0.0, iat_variance))
    iat_cv = iat_std / iat_mean if iat_mean > 0 else 0.0
else:
    iats = pd.Series(dtype="float64")
    iat_mean = iat_variance = iat_cv = 0.0
results["iat_mean"] = round(iat_mean, 6)
results["iat_variance"] = round(iat_variance, 6)
results["iat_cv"] = round(iat_cv, 4)

if ip_df.empty:
    results["num_producers"] = 0
    results["num_consumers"] = 0
else:
    sent = ip_df.dropna(subset=["src_ip"]).groupby("src_ip", sort=False)["length"].sum().rename("sent")
    received = ip_df.dropna(subset=["dst_ip"]).groupby("dst_ip", sort=False)["length"].sum().rename("received")
    ledger = pd.concat([sent, received], axis=1).fillna(0.0)
    totals = ledger["sent"] + ledger["received"]
    pcr = (ledger["sent"] - ledger["received"]) / totals.where(totals != 0)
    results["num_producers"] = int((pcr > 0.2).sum())
    results["num_consumers"] = int((pcr < -0.2).sum())

flow_columns = ["src_ip", "dst_ip", "src_port", "dst_port", "protocol"]
if total_packets:
    tcp_flow_mask = df["has_ip"] & df["has_tcp"]
    tcp_flows = df.loc[tcp_flow_mask, ["src_ip", "dst_ip", "tcp_sport", "tcp_dport"]].copy()
    tcp_flows.columns = ["src_ip", "dst_ip", "src_port", "dst_port"]
    tcp_flows["protocol"] = "TCP"

    udp_flow_mask = df["has_ip"] & df["has_udp"]
    udp_flows = df.loc[udp_flow_mask, ["src_ip", "dst_ip", "udp_sport", "udp_dport"]].copy()
    udp_flows.columns = ["src_ip", "dst_ip", "src_port", "dst_port"]
    udp_flows["protocol"] = "UDP"

    flows_df = pd.concat([tcp_flows, udp_flows], ignore_index=True)
    flows_df = flows_df.dropna(subset=["src_ip", "dst_ip", "src_port", "dst_port"])
    flows_df = flows_df.drop_duplicates(subset=flow_columns)
else:
    flows_df = pd.DataFrame(columns=flow_columns)

flow_set = {
    (row.src_ip, row.dst_ip, int(row.src_port), int(row.dst_port), row.protocol)
    for row in flows_df.itertuples(index=False)
}
results["unique_flows"] = len(flow_set)
results["tcp_flows"] = sum(1 for flow in flow_set if flow[4] == "TCP")
results["udp_flows"] = sum(1 for flow in flow_set if flow[4] == "UDP")
reverse_matches = 0
for src_ip, dst_ip, src_port, dst_port, protocol in flow_set:
    reverse = (dst_ip, src_ip, dst_port, src_port, protocol)
    if reverse in flow_set:
        reverse_matches += 1
results["bidirectional_flows"] = reverse_matches // 2

protocol_counts = {
    "tcp": results["protocol_tcp"],
    "udp": results["protocol_udp"],
    "icmp": results["protocol_icmp"],
    "arp": results["protocol_arp"],
}
results["dominant_protocol"] = max(protocol_counts, key=protocol_counts.get)

has_port_scan = False
if total_packets:
    scan_df = df[df["has_ip"] & df["has_tcp"] & df["src_ip"].notna()].copy()
    for source, group in scan_df.groupby("src_ip", sort=False):
        total_tcp = len(group)
        if total_tcp < 50:
            continue
        port_counts = group["tcp_dport"].dropna().value_counts()
        unique_ports = int(len(port_counts))
        syn_only_ratio = float(group["syn_only"].sum()) / total_tcp
        if port_counts.empty:
            port_entropy = 0.0
        else:
            probabilities = port_counts / port_counts.sum()
            port_entropy = float(-(probabilities * probabilities.map(math.log2)).sum())
        if port_entropy > 6.0 and syn_only_ratio > 0.7 and unique_ports > 100:
            has_port_scan = True
            break

ppm_avg = results["packets_per_minute_avg"]
ppm_ratio = results["packets_per_minute_max"] / ppm_avg if ppm_avg > 0 else 0.0
has_dos_pattern = ppm_ratio > 20
has_beaconing = len(iats) > 0 and results["iat_cv"] < 0.5
is_traffic_benign = not (has_port_scan or has_dos_pattern or has_beaconing)
results.update({
    "has_port_scan": has_port_scan,
    "has_dos_pattern": has_dos_pattern,
    "has_beaconing": has_beaconing,
    "is_traffic_benign": is_traffic_benign,
})

if packet_count != total_packets:
    raise RuntimeError("PDML packet count does not match normalized event count")
if results["protocol_ip_total"] > results["total_packets"]:
    raise RuntimeError("IP packet count exceeds total packet count")
if results["tcp_flows"] + results["udp_flows"] != results["unique_flows"]:
    raise RuntimeError("Flow protocol partitions are inconsistent")
if results["bidirectional_flows"] * 2 > results["unique_flows"]:
    raise RuntimeError("Bidirectional flow count is inconsistent")
if total_packets and not (
    results["min_packet_size"] <= results["avg_packet_size"] <= results["max_packet_size"]
):
    raise RuntimeError("Packet-size statistics are inconsistent")

lines = OUTPUT_CSV.read_text(encoding="utf-8").splitlines(keepends=True)
rewritten = []
for line in lines:
    if line.startswith("#"):
        rewritten.append(line)
        continue

    if line.endswith("\r\n"):
        body, ending = line[:-2], "\r\n"
    elif line.endswith("\n"):
        body, ending = line[:-1], "\n"
    else:
        body, ending = line, ""

    if "," not in body:
        rewritten.append(line)
        continue

    metric_token, _old_value = body.split(",", 1)
    metric = metric_token.strip().strip('"')
    if metric in results:
        rewritten.append(metric_token + "," + serialise(results[metric]) + ending)
    else:
        rewritten.append(line)

temporary = OUTPUT_CSV.with_name(OUTPUT_CSV.name + ".tmp")
temporary.write_text("".join(rewritten), encoding="utf-8")
os.replace(temporary, OUTPUT_CSV)

print(json.dumps(results, indent=2, sort_keys=True))
PYTHON_SCRIPT

echo "Completed: ${CSV_FILE}"
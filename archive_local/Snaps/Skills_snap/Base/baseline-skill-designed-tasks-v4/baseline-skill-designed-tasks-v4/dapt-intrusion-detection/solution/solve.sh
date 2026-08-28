#!/usr/bin/env bash
set -euo pipefail

PCAP_FILE="${PCAP_FILE:-/root/packets.pcap}"
CSV_FILE="${CSV_FILE:-/root/network_stats.csv}"
[[ -r "$PCAP_FILE" ]] || { echo "Missing PCAP: $PCAP_FILE" >&2; exit 1; }
[[ -r "$CSV_FILE" ]] || { echo "Missing CSV template: $CSV_FILE" >&2; exit 1; }

python3 - "$PCAP_FILE" "$CSV_FILE" <<'PY'
from __future__ import annotations

import ipaddress
import math
import os
import re
import struct
import sys
from collections import Counter, defaultdict

pcap_path, csv_path = sys.argv[1:]


def entropy(counter: Counter) -> float:
    n = sum(counter.values())
    if not n:
        return 0.0
    return -sum((c / n) * math.log2(c / n) for c in counter.values())


def ipv4_text(raw: bytes) -> str:
    return str(ipaddress.IPv4Address(raw))


def link_payload(packet: bytes, linktype: int):
    """Return (ethertype, network-layer bytes). Supports common PCAP L2 types."""
    if linktype == 1:  # Ethernet
        if len(packet) < 14:
            return None, b""
        et = struct.unpack_from("!H", packet, 12)[0]
        off = 14
        while et in (0x8100, 0x88A8, 0x9100):  # VLAN/QinQ
            if len(packet) < off + 4:
                return None, b""
            et = struct.unpack_from("!H", packet, off + 2)[0]
            off += 4
        return et, packet[off:]
    if linktype == 101:  # DLT_RAW
        if not packet:
            return None, b""
        version = packet[0] >> 4
        return (0x0800 if version == 4 else 0x86DD if version == 6 else None), packet
    if linktype == 113:  # Linux cooked v1: protocol at bytes 14..15
        if len(packet) < 16:
            return None, b""
        return struct.unpack_from("!H", packet, 14)[0], packet[16:]
    if linktype == 276:  # Linux cooked v2: protocol first
        if len(packet) < 20:
            return None, b""
        return struct.unpack_from("!H", packet, 0)[0], packet[20:]
    raise RuntimeError(f"Unsupported PCAP linktype {linktype}")


def ipv6_transport(payload: bytes):
    if len(payload) < 40 or payload[0] >> 4 != 6:
        return None
    nh = payload[6]
    off = 40
    # Hop-by-hop, Routing, Destination, Mobility: len=(HdrExtLen+1)*8
    # Fragment: fixed 8. AH: (PayloadLen+2)*4. ESP cannot be decoded here.
    for _ in range(12):
        if nh in (0, 43, 60, 135):
            if len(payload) < off + 2:
                return None
            nxt = payload[off]
            size = (payload[off + 1] + 1) * 8
        elif nh == 44:
            if len(payload) < off + 8:
                return None
            nxt, size = payload[off], 8
        elif nh == 51:
            if len(payload) < off + 2:
                return None
            nxt = payload[off]
            size = (payload[off + 1] + 2) * 4
        else:
            return nh
        if size <= 0 or len(payload) < off + size:
            return None
        nh, off = nxt, off + size
    return None


# Aggregates: no decoded-packet table, XML, dataframe, or graph object is kept.
total_packets = 0
total_bytes = 0
min_size = None
max_size = 0
timestamps = []
protocol = Counter()
src_ip_count = Counter()
dst_ip_count = Counter()
src_port_count = Counter()
dst_port_count = Counter()
nodes = set()
edges = set()
out_neighbors = defaultdict(set)
in_neighbors = defaultdict(set)
sent_bytes = Counter()
recv_bytes = Counter()
flows = set()
scan_tcp_total = Counter()
scan_syn_only = Counter()
scan_dst_ports = defaultdict(Counter)

with open(pcap_path, "rb") as f:
    gh = f.read(24)
    if len(gh) != 24:
        raise RuntimeError("Truncated PCAP global header")
    magic = gh[:4]
    if magic == b"\xd4\xc3\xb2\xa1":
        endian, scale = "<", 1_000_000.0
    elif magic == b"\xa1\xb2\xc3\xd4":
        endian, scale = ">", 1_000_000.0
    elif magic == b"M<\xb2\xa1":
        endian, scale = "<", 1_000_000_000.0
    elif magic == b"\xa1\xb2<M":
        endian, scale = ">", 1_000_000_000.0
    else:
        raise RuntimeError("Input is not classic PCAP (pcapng is not accepted by this task)")
    _magic, major, minor, _tz, _sigfigs, snaplen, linktype = struct.unpack(endian + "IHHIIII", gh)
    if major != 2 or snaplen <= 0:
        raise RuntimeError("Invalid PCAP header")

    while True:
        ph = f.read(16)
        if not ph:
            break
        if len(ph) != 16:
            raise RuntimeError("Truncated PCAP record header")
        ts_sec, ts_frac, incl_len, orig_len = struct.unpack(endian + "IIII", ph)
        if incl_len > max(snaplen, 16 * 1024 * 1024):
            raise RuntimeError(f"Implausible captured packet length {incl_len}")
        packet = f.read(incl_len)
        if len(packet) != incl_len:
            raise RuntimeError("Truncated PCAP packet data")

        total_packets += 1
        total_bytes += incl_len
        min_size = incl_len if min_size is None else min(min_size, incl_len)
        max_size = max(max_size, incl_len)
        timestamps.append(ts_sec + ts_frac / scale)

        et, net = link_payload(packet, linktype)
        if et == 0x0806:
            protocol["arp"] += 1
            continue
        if et == 0x86DD:
            nh = ipv6_transport(net)
            if nh == 6:
                protocol["tcp"] += 1
            elif nh == 17:
                protocol["udp"] += 1
            continue
        if et != 0x0800 or len(net) < 20 or net[0] >> 4 != 4:
            continue

        ihl = (net[0] & 0x0F) * 4
        if ihl < 20 or len(net) < ihl:
            continue
        protocol["ip"] += 1
        proto = net[9]
        src = ipv4_text(net[12:16])
        dst = ipv4_text(net[16:20])
        src_ip_count[src] += 1
        dst_ip_count[dst] += 1
        nodes.add(src); nodes.add(dst)
        edges.add((src, dst))
        out_neighbors[src].add(dst)
        in_neighbors[dst].add(src)
        sent_bytes[src] += incl_len
        recv_bytes[dst] += incl_len

        frag_word = struct.unpack_from("!H", net, 6)[0]
        frag_offset = frag_word & 0x1FFF
        transport = net[ihl:]
        if proto == 1:
            protocol["icmp"] += 1
            continue
        if proto not in (6, 17):
            continue

        # Wireshark only exposes transport ports on an initial/reassembled transport header.
        if frag_offset != 0 or len(transport) < 4:
            continue
        sport, dport = struct.unpack_from("!HH", transport, 0)
        if proto == 6:
            protocol["tcp"] += 1
            pname = "TCP"
            if len(transport) >= 14:
                flags = transport[13]
                scan_tcp_total[src] += 1
                scan_dst_ports[src][dport] += 1
                if (flags & 0x02) and not (flags & 0x10):
                    scan_syn_only[src] += 1
        else:
            protocol["udp"] += 1
            pname = "UDP"
        src_port_count[sport] += 1
        dst_port_count[dport] += 1
        flows.add((src, dst, sport, dport, pname))

if total_packets == 0:
    raise RuntimeError("PCAP contains no packets")

# Time metrics use timestamp ordering as required, independent of file ordering.
timestamps.sort()
first_ts, last_ts = timestamps[0], timestamps[-1]
duration = last_ts - first_ts
buckets = Counter(int((t - first_ts) / 60.0) for t in timestamps)
bucket_counts = list(buckets.values())
iats = [b - a for a, b in zip(timestamps, timestamps[1:])]
iat_mean = sum(iats) / len(iats) if iats else 0.0
iat_var = sum((x - iat_mean) ** 2 for x in iats) / len(iats) if iats else 0.0
iat_cv = math.sqrt(iat_var) / iat_mean if iat_mean > 0 else 0.0

all_ips = set(sent_bytes) | set(recv_bytes)
producers = consumers = 0
for ip in all_ips:
    sent, recv = sent_bytes[ip], recv_bytes[ip]
    denom = sent + recv
    if not denom:
        continue
    pcr = (sent - recv) / denom
    producers += pcr > 0.2
    consumers += pcr < -0.2

reverse_matches = sum(
    (dst, src, dport, sport, pname) in flows
    for src, dst, sport, dport, pname in flows
)

has_port_scan = False
for src, n in scan_tcp_total.items():
    if n < 50:
        continue
    ports = scan_dst_ports[src]
    unique_ports = len(ports)
    syn_ratio = scan_syn_only[src] / n
    port_ent = entropy(ports)
    if port_ent > 6.0 and syn_ratio > 0.7 and unique_ports > 100:
        has_port_scan = True
        break

ppm_avg = sum(bucket_counts) / len(bucket_counts)
ppm_max = max(bucket_counts)
has_dos = (ppm_max / ppm_avg) > 20 if ppm_avg else False
has_beacon = bool(iats) and iat_cv < 0.5

results = {
    "protocol_tcp": protocol["tcp"],
    "protocol_udp": protocol["udp"],
    "protocol_icmp": protocol["icmp"],
    "protocol_arp": protocol["arp"],
    "protocol_ip_total": protocol["ip"],
    "duration_seconds": round(duration, 2),
    "packets_per_minute_avg": round(ppm_avg, 2),
    "packets_per_minute_max": ppm_max,
    "packets_per_minute_min": min(bucket_counts),
    "total_bytes": total_bytes,
    "avg_packet_size": round(total_bytes / total_packets, 2),
    "min_packet_size": min_size or 0,
    "max_packet_size": max_size,
    "dst_port_entropy": round(entropy(dst_port_count), 4),
    "src_port_entropy": round(entropy(src_port_count), 4),
    "src_ip_entropy": round(entropy(src_ip_count), 4),
    "dst_ip_entropy": round(entropy(dst_ip_count), 4),
    "unique_dst_ports": len(dst_port_count),
    "unique_src_ports": len(src_port_count),
    "num_nodes": len(nodes),
    "num_edges": len(edges),
    "network_density": round(len(edges) / (len(nodes) * (len(nodes) - 1)), 6) if len(nodes) >= 2 else 0.0,
    "max_indegree": max((len(v) for v in in_neighbors.values()), default=0),
    "max_outdegree": max((len(v) for v in out_neighbors.values()), default=0),
    "iat_mean": round(iat_mean, 6),
    "iat_variance": round(iat_var, 6),
    "iat_cv": round(iat_cv, 4),
    "num_producers": producers,
    "num_consumers": consumers,
    "unique_flows": len(flows),
    "bidirectional_flows": reverse_matches // 2,
    "tcp_flows": sum(f[4] == "TCP" for f in flows),
    "udp_flows": sum(f[4] == "UDP" for f in flows),
    "is_traffic_benign": not (has_port_scan or has_dos or has_beacon),
    "has_port_scan": has_port_scan,
    "has_dos_pattern": has_dos,
    "has_beaconing": has_beacon,
}

# Sanity checks catch parser desynchronization instead of silently writing plausible junk.
if results["tcp_flows"] + results["udp_flows"] != results["unique_flows"]:
    raise RuntimeError("Flow partition invariant failed")
if not (results["min_packet_size"] <= results["avg_packet_size"] <= results["max_packet_size"]):
    raise RuntimeError("Packet-size invariant failed")


def fmt(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    return str(v)

with open(csv_path, "r", encoding="utf-8", newline="") as f:
    lines = f.readlines()
out = []
seen = set()
for line in lines:
    stripped = line.lstrip()
    if stripped.startswith("#") or "," not in line:
        out.append(line)
        continue
    ending = "\r\n" if line.endswith("\r\n") else "\n" if line.endswith("\n") else ""
    body = line[:-len(ending)] if ending else line
    metric_token, old = body.split(",", 1)
    metric = metric_token.strip().strip('"')
    if metric in results:
        out.append(metric_token + "," + fmt(results[metric]) + ending)
        seen.add(metric)
    else:
        out.append(line)

missing = set(results).intersection({re.sub(r'^"|"$', '', l.split(',',1)[0].strip()) for l in lines if ',' in l}) - seen
if missing:
    raise RuntimeError(f"Failed to update metrics: {sorted(missing)}")
tmp = csv_path + ".tmp"
with open(tmp, "w", encoding="utf-8", newline="") as f:
    f.writelines(out)
os.replace(tmp, csv_path)
PY

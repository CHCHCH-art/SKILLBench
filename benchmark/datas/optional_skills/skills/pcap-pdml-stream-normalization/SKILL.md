---
name: pcap-pdml-stream-normalization
description: "Convert packet captures to a streaming normalized packet-event representation using tshark PDML. Use when later network metrics need frame/time/length, protocol presence, IPv4 endpoints, transport ports, TCP flags, and SYN-without-ACK features without loading the whole capture."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Procedure

1. Read the capture path from the current the current task specification. Invoke `tshark` to emit PDML and parse the XML as a stream rather than loading the full document.
2. For each `<packet>`, emit one normalized event. Extract frame number, timestamp, and captured length; when the preferred captured-length field is absent, use the ordinary frame length as the reference fallback.
3. Record boolean layer presence for the protocol layers used by downstream metrics. Record IPv4 source/destination addresses only when the IPv4 layer exists. Record TCP and UDP source/destination ports when present.
4. Parse TCP flags and derive the reference behavioral feature `syn_only = SYN && !ACK` for each TCP packet.
5. Write normalized events as newline-delimited JSON in packet order. Clear processed XML elements and their preceding siblings during `iterparse` so memory use is bounded by the current packet rather than the complete PDML tree.

## Checks

Count emitted events and compare against parsed packet elements. Spot-check a TCP, UDP, and non-IPv4 packet against tshark fields. Downstream logic must distinguish layer absence from a missing field inside an existing layer.

If any required check fails and no reference retry/fallback is explicitly stated above, abort this step and do not emit downstream output.


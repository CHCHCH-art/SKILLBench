---
name: classic-pcap-streaming-network-metrics
description: "Parse classic PCAP traffic without loading packet objects, including Ethernet/VLAN, raw IP, Linux cooked v1/v2, IPv4 and IPv6 extension headers, then compute protocol, flow, entropy, graph, timing and byte metrics for intrusion-analysis CSV tasks."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference procedure
1. Read the 24-byte classic-PCAP global header. Recognize little/big-endian microsecond and nanosecond magic values; reject PCAPNG. Use each record's captured length as the packet length used by the reference metrics.
2. Decode link payloads exactly:
   - Ethernet: protocol starts at bytes 12:14, payload at 14. While EtherType is one of `0x8100,0x88A8,0x9100`, advance four bytes and read the encapsulated EtherType.
   - DLT_RAW (`101`): payload begins at byte 0 and IP version comes from its first nibble.
   - Linux cooked v1 (`113`): protocol is bytes 14:16 and payload begins at 16.
   - Linux cooked v2 (`276`): protocol is bytes 0:2 and payload begins at 20.
3. IPv4: header length is `(first_byte & 0x0f)*4`; protocol is byte 9; src/dst are bytes 12:16/16:20. Fragment offset is `flags_fragment & 0x1fff`. The reference increments its generic IP counter here. Parse TCP/UDP ports only on the first fragment and when at least four transport bytes exist; TCP flag features require at least 14 bytes. Count ICMP from protocol 1.
4. IPv6: start next-header walking at offset 40. For next headers `0,43,60,135`, extension length is `(HdrExtLen+1)*8`; fragment header `44` is 8 bytes; AH `51` length is `(PayloadLen+2)*4`; stop after at most 12 extension headers. Parse TCP/UDP at the resolved transport offset. The reference does not add IPv6 packets to its generic IP counter.
5. Accumulate protocol counts, captured-byte totals and packet-size min/max/mean; src/dst address and port counters; directed IP edges; per-IP sent/received bytes; 5-tuples `(src,dst,sport,dport,protocol)`; TCP SYN-without-ACK per-source features; and timestamps.
6. Sort timestamps. Bind the rate-bucket width and PCR thresholds from `Instruction.md`. Bucket by `int((t-first_t)/bucket_width)` and compute avg/max/min over nonempty buckets only. IAT variance is population variance. `iat_cv=sqrt(var)/mean`, or 0 when the mean is zero.
7. Shannon entropy is `-sum(p*log2(p))` over observed values. Directed density is `E/(N*(N-1))`, or 0 for fewer than two nodes. PCR is `(sent-recv)/(sent+recv)`.
8. For the bidirectional-flow output, preserve the reference convention: count every flow whose reverse 5-tuple exists as `reverse_matches`, then report `reverse_matches // 2`. Do not silently replace this with directional participation counting.
9. Preserve reference rounding: duration/rate average/average size to 2 decimals; entropies 4; density 6; IAT mean/variance 6; IAT CV 4.

## Checks

Require a valid classic-PCAP global header (`major == 2`, positive `snaplen`) and complete 16-byte record headers/packet payloads; truncated records are hard failures. For each decoded frame, never read a VLAN, IPv4, IPv6-extension, TCP, or UDP field past the captured bytes; unsupported link types abort, while packets that do not contain a valid supported network header are skipped exactly as the procedure specifies. After aggregation require: at least one packet; `tcp_flows + udp_flows == unique_flows`; `min_packet_size <= avg_packet_size <= max_packet_size`; nonnegative duration/IAT variance/entropy; network density in `[0,1]`; and an even `reverse_matches` count before integer-halving into bidirectional pairs. Parser desynchronization, nonfinite aggregate values, or a failed flow-partition invariant aborts output rather than writing plausible-looking metrics.

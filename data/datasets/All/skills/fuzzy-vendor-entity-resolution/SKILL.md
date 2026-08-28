---
name: fuzzy-vendor-entity-resolution
description: "Resolve normalized invoice vendor-name keys against approved vendors using the composite RapidFuzz scorer, deterministic top-candidate ordering, edit-distance allowances, and fixed acceptance thresholds. Preserve raw invoice/vendor fields separately; this step returns only the resolved vendor identity and match audit data."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check`. If it fails, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Procedure

1. Consume only `vendor_name_norm` as the query and approved vendors' normalized names as candidates. Raw vendor names remain attached to their records but are not similarity inputs.
2. Candidate score is:

   ```text
   max(fuzz.ratio(query,candidate),
       fuzz.WRatio(query,candidate),
       fuzz.token_set_ratio(query,candidate))
   ```

3. Use `process.extract` with this scorer and retain at most the top **5** candidates in returned order. Record rank, score, and Levenshtein edit distance for audit.
4. Final resolution considers only the top-ranked candidate:
   - exact normalized-name equality -> accept;
   - otherwise let `longest=max(len(query),len(candidate))`; allowed edits are `1` for `<12`, `2` for `<24`, otherwise `3`;
   - score `>=85` -> accept;
   - score `>=70` and edit distance within the allowance -> accept;
   - otherwise unresolved/null.
5. Return the resolved approved-vendor key/record. Do not mutate `vendor_name_raw`, `iban_raw`, `po_number_raw`, or any report-facing value.

## Checks

Require deterministic candidate ordering and exactly one final resolution decision per invoice. The stored resolved vendor key must refer to the same candidate whose normalized name/score was accepted. Do not fall through to candidate rank 2+ after rejecting rank 1. Abort on duplicate/ambiguous vendor primary keys or mismatch between recorded candidate index and resolved vendor record.

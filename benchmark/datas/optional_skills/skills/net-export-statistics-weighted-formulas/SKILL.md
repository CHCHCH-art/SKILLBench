---
name: net-export-statistics-weighted-formulas
description: "Populate spreadsheet formulas for an entity-level derived percentage, period-wise descriptive statistics, and a weighted mean using already-populated lookup blocks. Bind all ranges from the current task specification, compute independent expected values, and add formula/cache entries to the same finalization manifest."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check`. If it fails, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Runtime bindings

Bind from the current task specification/workbook:

- the three prerequisite lookup blocks used as numerator component A, numerator component B, and denominator/weight;
- entity-row and period-column alignment;
- the target range for the derived percentage;
- the requested statistic functions and target rows/ranges;
- the requested percentile probabilities;
- the target range for the weighted mean.

Do not infer fixed row numbers, a fixed entity count, or a fixed period count from this SKILL.

## Mandatory execution sequence

1. Reopen the workbook after the lookup-population checkpoint. Refuse to continue if any prerequisite target cell lacks a numeric cache. Do not derive values from blank formula cells.
2. Verify structural alignment before computing formulas: for each entity/period, the three prerequisite cells must refer to the same entity and period.
3. For each entity/period, write the derived percentage formula:

   ```text
   IFERROR((<component_a_cell>-<component_b_cell>)/<denominator_cell>*100,0)
   ```

   Independently compute the same value. If the denominator is zero, the expected cache is `0`, matching the formula fallback.
4. After populating the complete derived-percentage block, checkpoint it immediately: every bound target cell must have a formula and numeric expected value before statistics are generated.
5. For each period, generate exactly the descriptive statistics required by the current task over that period's entity-level derived-percentage cells. When the requested functions include the common set, use spreadsheet formulas equivalent to `MIN`, `MAX`, `MEDIAN`, `AVERAGE`, and inclusive percentile.
6. Compute inclusive percentile caches deterministically. For sorted values `x[0..n-1]` and probability `p`:

   ```text
   r = (n - 1) * p
   lo = floor(r)
   hi = ceil(r)
   percentile = x[lo]                         if lo == hi
                x[lo] + (r-lo)*(x[hi]-x[lo]) otherwise
   ```

7. For each period, generate the weighted-mean formula:

   ```text
   IFERROR(SUMPRODUCT(<percentage_range>,<weight_range>)/SUM(<weight_range>),0)
   ```

   Independently compute `sum(value_i * weight_i) / sum(weight_i)`, using `0` when the weight sum is zero.
8. Add every derived/statistic/weighted-mean cell to the same formula/cache manifest used by the lookup stage. Do not create a second disconnected output path or workbook.
9. Patch the complete manifest into one final workbook and run the final OOXML/cache verification stage. Do not finish after merely calculating values in Python memory.

## Checks

For every period, require:

- prerequisite lookup cells are populated and numeric before derived formulas are built;
- entity ordering matches across all prerequisite blocks;
- derived formulas reference the corresponding cells from the same entity/period;
- the derived block contains exactly one populated value per bound entity/period;
- statistic formulas span exactly the intended derived values for that period;
- weighted-mean weights come from the aligned denominator/weight block for the same entities and period;
- every generated formula has an independent numeric expected value;
- all manifest cells are eventually present in the final task-bound workbook, not only in an intermediate file.

Abort on missing prerequisite cells, row/period misalignment, empty statistic ranges, invalid percentile inputs, or formula/cache disagreement.

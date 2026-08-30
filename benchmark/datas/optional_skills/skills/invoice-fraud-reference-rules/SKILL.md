---
name: invoice-fraud-reference-rules
description: "Apply ordered invoice-fraud checks after PDF extraction and fuzzy vendor resolution, joining approved-vendor and purchase-order data with normalized keys while emitting report fields from preserved raw invoice values. Enforce one first-applicable reason per flagged page and Decimal amount comparison."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check`. If it fails, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Runtime bindings

Read from the current task specification:

- output path and JSON field names;
- required fraud-reason labels and their precedence;
- amount tolerance;
- required null convention and page indexing.

## Procedure

1. Join each staged invoice to its resolved approved vendor, then join its normalized PO key to the purchase-order table. Preserve the invoice's raw fields alongside these joined comparison records.
2. Evaluate exactly one reason in the task-specified precedence. The procedure's decision structure is:

   ```text
   unresolved vendor
   else normalized invoice IBAN != approved normalized IBAN
   else missing normalized PO or no matched purchase-order row
   else abs(Decimal(invoice_amount)-Decimal(po_amount)) > <task_amount_tolerance>
   else purchase-order vendor ID != effective invoice vendor ID
   else not fraudulent
   ```

   For the last comparison, use the invoice vendor-ID key when present; otherwise use the resolved approved-vendor ID.
3. Stop at the first applicable reason. Do not append multiple reasons for one invoice.
4. Exclude invoices with no reason from the report.
5. Build every flagged JSON object from the correct representation:

   ```text
   page number     <- staged 1-based page number
   vendor name     <- vendor_name_raw
   invoice amount  <- numeric value from the staged Decimal
   IBAN            <- iban_raw, NOT iban_norm
   PO number       <- po_number_raw only if the PO successfully matched;
                      otherwise the task/reference null representation
   reason          <- first applicable task-bound reason label
   ```

   This raw-vs-normalized separation is mandatory. A comparison key such as `FR...` with punctuation removed must never replace the raw invoice spelling in JSON.
6. Preserve source page order when serializing the flagged list.

## Checks

Before writing JSON, assert for every emitted row:

- `output.vendor_name == staged.vendor_name_raw`;
- `output.iban == staged.iban_raw` including interior `_`, `-`, or spaces captured from the page;
- if a PO matched, `output.po_number == staged.po_number_raw`; if no PO matched, output the required null value;
- normalized values are used only in joins/comparisons and never substituted into report-facing raw fields;
- at most one reason exists and it is the first applicable rule;
- amount comparison is performed in `Decimal`, not binary float;
- output rows remain in ascending source-page order.

Abort rather than serialize if any report-facing raw field has been replaced by its normalized key or if a page classified as Invalid PO arose from an earlier parser failure rather than a genuine unmatched PO key.

# Break analysis and pilot pack - customer overlay of the ops suite

Release: 2026-11-11 (build F). Product: `ops-framework/docs/BREAK_ANALYSIS.md`, `ops-framework/docs/PILOT_PACK.md`,
`ops-framework/docs/EXPLAINABLE_RESULTS.md`. This document holds only what is this landscape's own: the clearing
accounts of the payment engine, the bank transaction codes of its banks, the overlay links and rules, the business
process that runs it, the decisions to take. **Everything is delivered inactive** until its VERIFY item is closed.

> **First principle:** the product knows that a clearing-account reference must net to zero and how to name the
> reason when it does not; only this landscape knows which bank code means "redeposit" and that its assignment field
> carries the payment document.
>
> **Analogy:** the product is the cloakroom procedure; the overlay is this theatre's ticket colours.

## 1. Facts the overlay rests on (payment engine reference, confirmed 2026)

- The disbursement clearing account keeps every posting as an open item; reconciliation asks whether debit and credit
  lines **net to zero within a ZUONR group**. No manual postings exist, so breaks are systemic: reference misalignment
  on clubbed settlement debits, a new AUGBL on reversals, bank cumulation.
- JPMC sends **143 / 165 / 166** as cumulated amounts; multiple **468**s or cumulated 143 / 166 on one reference block
  F.13 (which matches on ZUONR). **468**s post automatically via EBS; **165**s are manual.
- Unmapped / new BTCs (e.g. **143, 452**) post to the wrong clearing account or stay unprocessed. FEBEP: XBLNR never
  blank for BAI 452.
- Join paths: bank line -> payment (methods E-L) `FEBEP-CHECT = BSEG-XREF2 = DFKKOP-AUGBL`; BSEG-ZUONR carries AUGBL for
  ACH and card; cheque `DFKKCR-DOC1R = DFKKOP-AUGBL`, `DFKKCR-ZTNUM = FEBEP-CHECT`; return `DFKKRP-SELW1 = DFKKOP-AUGBL`.
- Variance buckets of the BlackLine exception review vs FAGLB03 month end: timing (last-days statements arrive next
  month), retrieval cut-off in the next period, returns processed next month / after the extract, 468 without returns
  lot (delayed redeposit), cheque exceptions (duplicate cashing, multiple paid / stop codes), retry / redeposit, new
  BTCs, others. The BlackLine extract = all open BSEG items of the clearing account on the 2nd business day of the next
  month - the break analysis with the month-end key date, run on that day, is its SAP-native twin.

## 2. What the overlay delivers

| Piece | Rows | State |
|---|---|---|
| Business process `CD_HCK` / `GL_CLEAR_BRK` (`config/processes/CD_HCK_GL_CLEAR_BRK.json`, scaffolded) | process (catalogue process `FICA_GL_TRANSFER`), check `GL_BREAKS` (`ZCL_CA_OPS_CHK_BREAK`, company-code aware), covered by control `DAILY_RECON`, alert rule `HCK_BREAKS`, purge target `BREAK` | inactive |
| Accounts `config/breaks/zca_ops_brkacc.csv` | one row per active `ZCD_HCK_RCSET` set (company code, clearing account), process `GL_CLEAR_BRK`, group cap 50 000 | placeholder, inactive (V141) |
| Links `config/links/overlay.json` | `CD_GLITEM_TO_STMT_LINE` (assignment -> `FEBEP-CHECT`), `CD_GLITEM_TO_RETURN` (-> `DFKKRP-SELW1`), `CD_GLITEM_TO_CHEQUE` (-> `DFKKCR-DOC1R`) | inactive, quality P (V139) |
| Overlay rules `config/breaks/zca_ops_brkrul.csv` / `_brkcnd.csv` (area `CD_HCK`, prefix `CD_`) | see §3 | inactive (V139, V140) |
| Bucket `BANK_CUMULATION` | `config/breaks/zca_ops_brkbkt.csv` | inactive (decision D-F3) |
| Code lists `config/param_values.csv` (area `CA_OPS`) | `BRK_BTC_NEW` 143,452 · `BRK_BTC_REDEPOSIT` 468 · `BRK_BTC_CUMULATED` 143,165,166 · `BRK_BTC_CHEQUE` not delivered (V140) | values |

The BAI codes appear **only** here - the product's parameters are blank.

## 3. Overlay rules (before the product rules: sequence 50-90 < 100)

| Rule | Seq | Bucket | Conditions |
|---|---|---|---|
| `CD_NEW_BTC` | 50 | NEW_BTC | a bank line of the clearing line has a code of `BRK_BTC_NEW` |
| `CD_REDEP_NO_LOT` | 60 | REDEPOSIT_NO_LOT | a bank line with a code of `BRK_BTC_REDEPOSIT` exists **and** no returns lot item (`DFKKRP`) for the payment |
| `CD_RETRY_REDEP` | 70 | RETRY_REDEPOSIT | a redeposit bank line **and** a returns lot item - presented again |
| `CD_CHEQUE_EXC` | 80 | CHEQUE_EXCEPTION | a cheque (`DFKKCR`) **and** two or more bank lines with codes of `BRK_BTC_CHEQUE` (duplicate cashing / paid and stop) |
| `CD_CUMULATED` | 90 | BANK_CUMULATION | a bank line with a code of `BRK_BTC_CUMULATED` (D-F3) |

Then the product rules (timing, retrieval, return later, retry pattern); OTHER otherwise. The offline check
`break_rules` of `tools/portable_checks.py` validates the overlay with the product rules.

## 4. Pilot (shadow mode) of this landscape

Areas `CD_HCK` (break analysis, reconciliation checks) and the areas already monitored; baselines per check in
`ZCA_OPS_PILOTBL` (e.g. the month-end BlackLine review for `GL_BREAKS`, the next-morning report for the reconciliation
checks) - **values from the team's incident history, never from production rows**; export to the logical path
of `PILOT_EXPORT_PATH` (a path of the RTB share, V144). Alerts of the pilot areas to the RTB support list only.

## 5. Decisions for the user

| ID | Decision | Proposal |
|---|---|---|
| D-F1 | A finding raised again **unchanged** after a sign-off no longer reopens the control (before: any finding after the sign-off) | accept (reopen with reason NEW / STATUS / AMOUNT / CONFIG / WORSE) |
| D-F2 | Group bucket = the bucket of its **oldest open line** (not the best of its lines) | accept - the line open longest is the break |
| D-F3 | Bank cumulation (143 / 165 / 166) as its own explained bucket `BANK_CUMULATION`, or left OTHER | own bucket, after V140 |
| D-F4 | 143 is in both "new / unmapped" and "cumulated": `CD_NEW_BTC` (seq 50) wins | confirm which reading applies per bank |
| D-F5 | Break analysis on ACDOCA (D-C8 kept): group and line reads stay on the table until BRK-PV1 / BRK-PV2 | accept |
| D-F6 | Unexplained break = exception after `BRK_UNEXPLAINED_DAYS` = 5 days; one finding per group, at most 500 per account | confirm the age and the cap with the reconciliation lead |

## 6. VERIFY

| ID | Kind | Item |
|---|---|---|
| V139 | VERIFY-SE11 / QA1 | The assignment (ZUONR) of a clearing-account line carries the payment document (AUGBL) for ACH, card **and cheque** clearing accounts (confirmed for ACH and card; cheque open); then the three overlay links are switched on (`active`) and the overlay rules activated; the to-field indexes `FEBEP-CHECT`, `DFKKRP-SELW1`, `DFKKCR-DOC1R` (BRK-PV3) |
| V140 | Business / bank | The code lists: `BRK_BTC_NEW` (143, 452 - new / unmapped), `BRK_BTC_REDEPOSIT` (468), `BRK_BTC_CUMULATED` (143, 165, 166), `BRK_BTC_CHEQUE` (paid / stop codes of the cheque banks - not delivered); D-F3 / D-F4 decided |
| V141 | Configuration / PlanViz | One account row per active `ZCD_HCK_RCSET` set (company code, clearing account); `BRK_LOOKBACK_DAYS` covers the oldest open line of the busiest account; BRK-PV1 / BRK-PV2 on the busiest disbursement clearing account on a 2-million-payment day |
| V144 | Configuration | Pilot: baselines of the pilot checks in `ZCA_OPS_PILOTBL` with their source; logical path / file of `PILOT_EXPORT_PATH` / `PILOT_EXPORT_FILE` on the RTB share; `S_DATASET` of the job user |

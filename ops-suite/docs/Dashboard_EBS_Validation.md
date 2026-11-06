# EBS validation dashboard — statements, lines, findings, returns and NOCs

> **First principle:** a bank statement is only "fine" when the last completed validation looked at it and left no open finding — the page shows both the verdict and when it was reached, and it never calls a statement clean.
> **Analogy:** a customs hall's arrivals screen — each container (statement) shows whether it is held, cleared or still waiting for inspection, which inspector shift last scanned the hall, and a screen that stopped updating is itself an alarm.

Status 2026-11-06: written and statically checked offline (abaplint: CDS parsed, ABAP checked, 0 issues). **Not activated in SAP, ABAP Unit not executed** — the first DV1 import is the test. Items marked **VERIFY-ADT** / **VERIFY-SE11** are confirmed at activation. Same pattern as the file monitoring dashboard (`Dashboard_File_Monitoring.md`); one of the four area dashboards of the production-support overview page (`Dashboard_Production_Support.md`).

## 1. What the support team sees

Fiori elements **analytical list page** (OData V4, service `ZUI_CD_EBS_DASH`, main entity `EbsStatement`) plus two more apps on the same service (list report / ALP on `EbsFinding` and `EbsRun`). Everything is read-only; findings are worked in the owned-exceptions app (`ZUI_CD_OPS_EXC_O4`).

| Area | Content |
|---|---|
| Header / KPI | **Validation as of** (end of the last completed EBS run), age in minutes, stale flag (red when older than 26 hours or no completed run) |
| Filter bar | Company code, house bank, house bank account ID, statement date, validation status, worst open severity |
| Chart (default) | Statements by **house bank**, stacked by **validation status**. Alternatives: lines and lines with findings per statement date; open findings (B / E / W) by house bank and account ID |
| Table | One row per imported statement (FEBKO, statement date in the last 31 days): date, company code, house bank, account ID, statement number, status (coloured), worst severity, lines, posted lines, open findings, duplicates, as of |
| Object page | Statement attributes, line and finding counts, validation as of; **Lines** (FEBEP) → line object page with its **open findings** and **returns / NOC lot items**; **Open findings** of the statement and its lines |
| Lines (`EbsLine`) | Every FEBEP line as its own record (BAI code, posting rule, debit / credit, amount, currency, dates, bank reference, posting document, status). **Amount totals by BAI code**: presentation variant `AmountByCode` sums `Amount` (and the line count) per BAI code, debit / credit and currency, with a total per BAI code; chart *Line amounts by BAI code* (stacked by debit / credit). Amounts are never added across currencies — the currency is part of every group; filter one currency for a single total. Removing the grouping returns to the individual lines |
| App "EBS findings" (`EbsFinding`) | Findings by **rule and severity** (default chart), by BAI code and category; selection variant *Open*; one row per finding with rule text, check code, owner, due date |
| App "EBS runs" (`EbsRun`) | Run history: **lines by outcome per run date** (passed, warning, failed, blocked, not evaluated); findings of each run |

## 2. Freshness — the "as of" rule

- The statements and lines are read **live** from FEBKO / FEBEP; the **verdict** (findings) is what the last EBS run (`ZCD_EBS_VALIDATE`, `ZCL_CD_EBS_ENGINE`) stored in `ZCD_OPS_FINDING`.
- **As of** = `ENDED_AT` of the last **completed** EBS run in `ZCD_OPS_RUN`: area EBS, not test mode, status S, W, E or N (N = no data — the run looked and found nothing; still a complete look). Running (R) and aborted (A) runs never move it. Any variant counts.
- **Stale** after **26 hours** (daily run + 2 h slack = `HCK_MAX_AGE_HOURS` default) or when there is no completed run. Literal in `ZR_CD_EbsAsOf` (CDS cannot read `ZCD_OPS_PARAM`); `AgeMinutes` and `StaleAfterMinutes` are exposed so a tile can be stricter.
- A statement imported **after** the as-of run has no finding yet and shows NO_FINDINGS — compare the statement date with the as-of time; FEBKO carries no import time stamp that the dashboard uses (VERIFY-SE11 if one is wanted).

## 3. Validation status (statement and line)

| Status | Rule (open findings = disposition O or A of the statement and its lines) | Colour |
|---|---|---|
| BLOCKED | An open finding of severity **B** | red |
| ERROR | An open **E** finding | red |
| POSTING_INCOMPLETE | (statement only) An open **S13 POSTING_INCOMPLETE** — posting-dependent rules were not evaluated for lines expected to post (`EBS_VALIDATION.md` §A0) | yellow |
| WARNING | An open **W** finding | yellow |
| NO_FINDINGS | No open finding — **not** "clean": the statement may not have been validated yet (§2) | green |

Resolved (R), waived (W), superseded (S) and information (I) findings never count. Duplicates = rules **S07** (statement), **R09** (in the statement), **R22** (earlier statements of the account). Literals in `ZI_CD_EbsFinding` / `ZR_CD_EbsStmt` (values of `config/zcd_ebs_rule_def.csv`).

**Unevaluated lines** come from the run counters: `ZCL_CD_EBS_ENGINE->COUNT_LINES` counts every line in `TOTAL_ITEMS` and in at most one of passed / warning / failed / blocked; a line expected to post but not posted is counted in none, so **not evaluated = total − passed − warning − failed − blocked** (`ZI_CD_EbsRunBase`). Lines of a rule group whose rule had a PLUGIN_ERROR are counted as failed by the engine (as in the run message).

## 4. Returns and NOCs by reason

`EbsReturnNoc` (`ZR_CD_EbsRetNoc`) lists, per bank line of the last 31 days, the lot items behind it:

| Kind | Source | Link (confirmed) | Reason |
|---|---|---|---|
| RETURN | Returns lot item **DFKKRP** (+ lot status DFKKRK-STARS) | `DFKKRP-SELW1 = FEBEP-CHECT` (= DFKKOP-AUGBL, methods E G H I J K L) | **DFKKRP-RLGRD** (VERIFY-SE11) |
| NOC | NOC lot item **DFKKNRP** (lot KEYN1, item POSNA) | `DFKKNRP-INFOF` (payment document or payment reference, CHAR 50) = FEBEP-CHECT, both **without leading zeros** | **DFKKNRP-FLGRD** (VERIFY-SE11) |

FEBEP holds **no** return reason, and DFKKRP holds **no** NOC code — the dashboard never reads either. INFOF is not a key and has no known index (VERIFY-SE11): the join is driven by the bounded line set. Chart: lot items by reason, stacked by kind; drill from the line object page.

## 5. Tiles, KPI and overview-page cards

Service binding `ZUI_CD_EBS_DASH_O4` (`/sap/opu/odata4/sap/zui_cd_ebs_dash_o4/srvd/sap/zui_cd_ebs_dash/0001/`, VERIFY-ADT).

| Tile | Request | Red when |
|---|---|---|
| **Stale validation** | `ValidationAsOf/$count?$filter=IsStale eq true` | ≥ 1 |
| Blocked / error statements | `EbsStatement/$count?$filter=ValidationStatus eq 'BLOCKED' or ValidationStatus eq 'ERROR'` | ≥ 1 |
| Posting incomplete | `EbsStatement/$count?$filter=ValidationStatus eq 'POSTING_INCOMPLETE'` | ≥ 1 |
| Lines not evaluated (latest run) | `EbsKpi?$filter=IsLatest eq true&$select=UnevaluatedLineCount` | > 0 |
| EBS validation dashboard (app tile) | Semantic object `ZCDEbsValidation`, action `analyze` | — |

**KPI entity `EbsKpi`** (`ZC_CD_EbsKpi`): one row per run date = the **last completed run of that date** (`ZI_CD_EbsRunDay`; an intraday re-run validates the same statements again, so runs of a day are never added). Lines validated / passed / warning / failed / blocked / not evaluated, findings by severity, POSTING_INCOMPLETE, duplicates, unmapped codes, statements with findings, RAG, `IsLatest` (= the as-of run), as-of / age / stale. Selection variant `Latest`, chart `LinesByOutcome`, data points `Lines`, `Failed`, `Blocked`, `Unevaluated`, `PostingIncomplete`, `ValidationAge`.

**List entity `LatestProblem`** (`ZC_CD_EbsProblem`): open B / E findings and open POSTING_INCOMPLETE, newest first, `maxItems` 10.

## 6. Drill-down path

`EbsRun` → findings of the run; `EbsStatement` (FEBKO) → **lines** (FEBEP) → line **findings** and **returns / NOC lot items**; the statement's open findings directly. A run stores no list of the statements it validated — statements without findings leave no trace in a run, so "run → statement" goes through the run's findings (`StmtObjectKey`, `ObjectKey` columns). Keys: statement `FEB<KUKEY>`, line `FEB<KUKEY>/<ESNUM without leading zeros>` (`ZCL_CD_EBS_FINDING=>LINE_KEY`). Bank-file statements validated before import (keys `S0001`…) appear only in `EbsFinding` (source FILE). Reprocessing (FEBAN) stays outside the dashboard (read-only scope; `ZCDBankStatement-reprocess` not created, `Implementation_Order.md` 1c.7).

## 7. Limits and sensitive data

- **Window: 31 days** — statements by statement date (FEBKO-AZDAT), runs by start date, findings: open ones always, closed ones created in the last 31 days. Older evidence: `ZCD_EBS_VALIDATE` / SE16 / the exceptions app.
- No balances and no **bank account number**: statement findings carry the account number in GROUP1 — shown only masked (`****` + last 4); the message of statement / file findings of the **file source** (may contain the account number, parser texts) is not exposed. House bank account **ID** (HKTID) is a short key, not the number.
- Amounts: line amounts in the line currency (else statement currency); finding amounts DEC without currency semantics — slice by currency before reading totals.
- Company code (BUKRS) is not part of the DCL (area-wide like the EBS run); add it to the statement / line grants if required.

## 8. Objects (package `ZCD_OPS_EBS`, `src/ebs`, read-only; shared basic views in `src/core`)

| Object | Type | Role |
|---|---|---|
| `ZI_CD_EbsRunLast` | view (aggregate, one row) | End of the last completed EBS run |
| `ZI_CD_EbsRunBase`, `ZI_CD_EbsRunFind`, `ZI_CD_EbsRunDay` | views | Runs of 31 days with counters / unevaluated; findings per run; last completed run per day |
| `ZI_CD_EbsFinding`, `ZI_CD_EbsStmtExc`, `ZI_CD_EbsLineExc` | views | Findings (bounded, keys derived, account masked); open findings per statement / line |
| `ZI_CD_EbsStmtBase`, `ZI_CD_EbsLineBase`, `ZI_CD_EbsStmtLines` | views | FEBKO / FEBEP of 31 days with finding keys; lines per statement |
| `ZI_CD_EbsRetNocU` | view (UNION) | Lines × returns lot items / NOC lot items |
| `src/core/ZI_CD_ReturnItem`, `src/core/ZI_CD_NocItem` | views | DFKKRP (+ DFKKRK) with RLGRD; DFKKNRP with FLGRD and normalised INFOF — shared with the transaction dashboard |
| `ZR_CD_EbsAsOf` / `ZC_CD_EbsAsOf` | root / projection | As of, age, stale |
| `ZR_CD_EbsStmt` / `ZC_CD_EbsStmt` | root / projection (`@Aggregation.default`) | Dashboard rows (statement × as of), status, measures |
| `ZR_CD_EbsLine`, `ZR_CD_EbsFind`, `ZR_CD_EbsRetNoc`, `ZR_CD_EbsRun` (+ `ZC_`) | roots / projections | Lines, findings, returns / NOC, runs |
| `ZR_CD_EbsKpi`, `ZR_CD_EbsProblem` (+ `ZC_`) | roots / projections | KPI per day, latest problems |
| 8 metadata extensions `ZC_CD_EBS*` | DDLX | Charts, presentation / selection variants, facets, data points |
| `ZC_CD_EBSDASH` | DCL | `pfcg_auth( ZCD_OPS, ZCD_PE_AREA, ACTVT = '03' )` on the eight projections; rows carry `PaymentEngineArea` = EBS |
| `ZUI_CD_EBS_DASH` | service definition | `EbsStatement`, `EbsLine`, `EbsFinding`, `EbsReturnNoc`, `EbsRun`, `ValidationAsOf`, `EbsKpi`, `LatestProblem` |
| `ZUI_CD_EBS_DASH_O4` | service binding (OData V4 – UI) | Created in ADT |
| `ZCL_CD_EBS_DASH_CDS_TEST` | class (test holder) | CDS unit tests (§10) |

Existing classes are unchanged.

## 9. VERIFY-ADT / VERIFY-SE11

| Item | Where | Fallback if refused |
|---|---|---|
| `CONCAT` / `LTRIM` with NUMC operands (KUKEY, ESNUM) | `ZI_CD_EbsStmtBase`, `ZI_CD_EbsLineBase` | `cast( kukey as abap.char( 8 ) )` / `cast( esnum as abap.char( 5 ) )` first |
| `COUNT( DISTINCT )` and `MAX` in one element | `ZI_CD_EbsRunFind` | Drop StatementsWithFindings / LinesWithFindings |
| `UNION ALL` with CAST-aligned keys | `ZI_CD_EbsRetNocU` | Two entities (returns, NOCs) |
| `RIGHT( RTRIM( ) )` for the account mask | `ZI_CD_EbsFinding` | `substring( group1, length( group1 ) - 3, 4 )` or omit the column |
| CROSS JOIN of the as-of row; aggregate without GROUP BY | `ZR_CD_EbsStmt`, `ZR_CD_EbsRun`, `ZI_CD_EbsRunLast` | As the file monitoring dashboard §10 |
| Cyclic associations statement ↔ finding are **not** used (finding → statement is by key column only) | — | — |
| `$apply` on a transactional_query projection without BDEF | `ZC_CD_EbsStmt`, `ZC_CD_EbsLine`, `ZC_CD_EbsFind`, `ZC_CD_EbsKpi` | `@ObjectModel.supportedCapabilities: [ #ANALYTICAL_PROVIDER ]` |
| FEBKO / FEBEP fields beyond KUKEY, ESNUM, BUDAT, CHECT, XBLNR (BUKRS, HBKID, HKTID, AZNUM, AZDAT, WAERS, VORGC, VGINT, EPVOZ, KWBTR, KWAER, VALUT, BELNR, GJAHR) | base views | Same list as `ZCL_CD_EBS_FEB_DAO` (VERIFY-DDIC there) |
| **DFKKRP-RLGRD**, **DFKKNRP-FLGRD**, DFKKRP key (OPBEL + SELW1 unique?), DFKKRK-STARS; index on DFKKNRP-INFOF | `ZI_CD_ReturnItem`, `ZI_CD_NocItem` | Remove the reason element / add the lot key in ADT; ST05 the NOC join in QA1 |
| `cl_cds_test_environment` with `i_select_base_dependencies` over UNION / CROSS JOIN | test include | Double first-level views |

## 10. Tests

ABAP Unit in `ZCL_CD_EBS_DASH_CDS_TEST` (doubles of FEBKO, FEBEP, ZCD_OPS_FINDING, ZCD_OPS_RUN, ZCD_EBS_RULE_DEF, DFKKRP, DFKKRK, DFKKNRP; not executed offline):

| Class | Tests |
|---|---|
| `ltc_statement` (`ZR_CD_EBSSTMT`, `ZR_CD_EBSLINE`) | `status_follows_worst_finding`, `closed_findings_are_ignored`, `lines_counted_per_statement`, `line_status_from_line_finding`, `rows_carry_validation_as_of`, `amounts_total_per_bai_code` |
| `ltc_finding` (`ZR_CD_EBSFIND`) | `account_is_masked`, `file_stmt_message_hidden`, `line_key_gives_line_number` |
| `ltc_run` (`ZR_CD_EBSRUN`, `ZR_CD_EBSKPI`, `ZR_CD_EBSASOF`) | `unevaluated_is_the_remainder`, `run_counts_s13_and_duplicates`, `kpi_shows_last_run_of_day`, `as_of_skips_running_and_test`, `stale_when_no_completed_run`, `stale_after_26_hours` |
| `ltc_returns` (`ZR_CD_EBSRETNOC`) | `return_reason_from_dfkkrp`, `noc_reason_via_infof` |

## 11. QA1 cases

| ID | Case | Expected |
|---|---|---|
| EBD-01 | Run `ZCD_EBS_VALIDATE` (productive), open the dashboard | As of = end of that run; not stale; every statement of the window listed |
| EBD-02 | No EBS run for > 26 h (or QA1 without runs) | Header / rows stale (red); tile *Stale validation* = 1 |
| EBD-03 | Test-mode run, then an aborted run | As of does not move |
| EBD-04 | Statement with an unmapped BAI code (R14 B) | Status BLOCKED; line BLOCKED; finding listed with BAI code and rule text |
| EBD-04a | Statement with two 165 credit lines (100.00, 50.25 USD) and one 475 debit line (30.00 USD); Lines app, variant *Amounts by BAI code* | 165 / credit: 150.25 USD, 2 lines; 475 / debit: 30.00 USD, 1 line; a second currency appears as its own total, never added |
| EBD-05 | Statement imported before FEBP finished (S13) | Status POSTING_INCOMPLETE; latest run *not evaluated* > 0 = total − passed − warning − failed − blocked of `ZCD_OPS_RUN` |
| EBD-06 | Resolve the finding in the exceptions app and re-run | Status NO_FINDINGS; finding no longer open |
| EBD-07 | Duplicate entry (R09 / R22) | Duplicate count 1 on statement and run |
| EBD-08 | File-source run (bank file before import) with a balance error | Finding in `EbsFinding` (source FILE), message empty, account masked `****nnnn`; no statement row |
| EBD-09 | ACH return line (lot with RLGRD) and an NOC (DFKKNRP, INFOF with leading zeros) | `EbsReturnNoc`: RETURN with DFKKRP-RLGRD, NOC with DFKKNRP-FLGRD; SE16 matches |
| EBD-10 | Two runs on one day | KPI row of the day shows the later run only; `EbsRun` lists both |
| EBD-11 | User with ZCD_OPS ZCD_PE_AREA = FMON only | No rows in any entity; with EBS / 03: rows visible |
| EBD-12 | ST05 / PlanViz while using page, tiles and drill-down | SELECT only; FEBKO by AZDAT, FEBEP by KUKEY, findings by area / disposition; DFKKNRP join driven by the line set — record runtime |

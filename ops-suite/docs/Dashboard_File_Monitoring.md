# File monitoring dashboard — files received, at PRISM, sent, processed, acknowledged, rejected

> **First principle:** a dashboard is only as current as the last monitor run behind it — every number carries its "as of", and a monitor that stopped is shown as stale, never as a quiet day.
> **Analogy:** an airport arrivals board — each flight shows where it is now (landed, at the gate, delayed, cancelled), the board shows when it was last refreshed, and a frozen board is itself an incident.

Status 2026-11-06: written and statically checked offline (abaplint: CDS parsed, 0 issues; ATC-equivalent set: only the 3 documented exemptions). **Not activated in SAP, ABAP Unit not executed** — the first DV1 import is the test. Items marked **VERIFY-ADT** are release-dependent and are confirmed at activation.

This is one of four area dashboards (file monitoring, EBS validation, morning report / health checks, transactions in SAP) that a later step combines into the production-support **overview page (OVP)** and the "Production Support" launchpad space. Its KPI and latest-failures entities (§6) are shaped for those cards.

## 1. What the support team sees

One **analytical list page** (Fiori elements, OData V4) over every monitored file instance in `ZCD_FMON_FILE`:

| Area of the page | Content |
|---|---|
| Header / KPI | **Monitor as of** (end of the last completed FMON run), age in minutes, stale flag (red when older than 15 minutes or no completed run) |
| Filter bar | Source system, LOB, payment method, interface, direction, bank, business date, flow bucket, SLA status |
| Chart (default) | Files by **flow bucket**, stacked by payment method. Alternative views: files per business date (all / successful / rejected), records by source and LOB |
| Table | One row per file: business date, interface, direction, source, LOB, method, bank, file name, flow bucket (coloured), successful, SLA status (coloured), worst open severity, records, control total, ACK / NACK count, unprocessed items, open exceptions, last event, as of |
| Object page (drill-down) | Flow and interface attributes, counts and amounts, monitor as of; **events** (the audit trail: every source event with stage, time, source, reference, counts); **open exceptions** of the file (check code, SLA class, severity, owner, due date, message) |

Everything is **read-only**: no behaviour definition, no action, no write. Exceptions are worked in the owned-exceptions app (`ZUI_CD_OPS_EXC_O4`), stages corrected only in the manual-status app (`ZUI_CD_FMON_MAN_O4`).

## 2. Freshness — the "as of" rule

> **First principle:** "nothing failed" and "nothing was checked" look identical unless the check's time is on the page.
> **Analogy:** a thermometer reading is useless without the time it was read.

- The dashboard reads what `ZCD_FMON_MONITOR` stored; it does not read source tables live. It is refreshed by every monitor run (native SAP periodic job `ZCD_FMON_MONITOR_ALL` in SM36, every 5 minutes). PRISM milestones arrive faster: each PRISM status API call is processed within seconds by a background unit (bgPF), so PRISM stages and the SLA status they affect are near-instant (`PRISM_Status_API.md`).
- **As of** = `ENDED_AT` of the last **completed full** FMON run in `ZCD_OPS_RUN`: area `FMON`, variant `ALL` (whole monitor, `ZCL_CD_FMON_ENGINE`), not test mode, status S, W or E (`ZIF_CD_OPS_TYPES=>GC_RUN_STATUS`; E = finished with error findings, still a complete look). A running (R) or aborted (A) run, a test run and a single-interface run never advance the as-of time.
- **Stale** when the as-of time is older than **15 minutes** (3 × the 5-minute cadence) or there is no completed run at all. CDS cannot read `ZCD_OPS_PARAM`; the 15 minutes (900 s) are a literal in `ZR_CD_FmonAsOf` and the age in minutes is exposed, so a tile may apply a stricter threshold.
- Every dashboard row carries `AsOfAt`, `AsOfRunId`, `MonitorAgeMinutes`, `MonitorIsStale`; the entity `MonitorAsOf` holds the one as-of row (also when no file exists).
- Times are UTC time stamps; the browser shows them in the user's time zone.

## 3. Flow buckets — where the file is now

The bucket is the file's **current** position (mutually exclusive; the bucket counts add up to the file count). The terminal outcome wins over the stage. Stage values are the constants of `ZIF_CD_FMON_TYPES=>GC_STAGE`, written as CDS literals in `ZI_CD_FmonFlowFile` (CDS cannot read ABAP constants — a new stage needs this table and the view changed together).

| Bucket | Stage / outcome | Direction | Meaning |
|---|---|---|---|
| RECEIVED | FILE_RECEIVED | in | File arrived in SAP, not yet loaded |
| RECEIVED | GENERATED_IN_SAP | out | SAP generated the file, not yet handed over |
| RECEIVED | PRISM_DELIVERED ¹ | in | PRISM delivered the file to SAP |
| AT_PRISM | PRISM_RECEIVED ¹ | out / in | PRISM confirmed receipt (from SAP outbound; from bank / IRIS / source inbound) |
| SENT | SENT_TO_PRISM, FORWARDED_TO_BANK | out | Handed over to PRISM / forwarded to the bank, no answer yet |
| SENT | PRISM_DELIVERED ¹ | out | PRISM delivered the file to the bank / IRIS / source |
| PROCESSED | FILE_LOADED, FULLY_PROCESSED | in | Loaded / fully processed |
| ACKNOWLEDGED | ACK_RECEIVED | out | Bank acknowledged the file |
| REJECTED (rejected / errored) | NACK_REJECTED, FAILED, PRISM_FAILED ¹ | out / in | Bank rejected, inbound processing failed, or PRISM could not process / deliver |
| PARTIAL | PARTIALLY_PROCESSED | in | Some items not accounted for (returns / NOC lots) — see unprocessed items |
| UNKNOWN | anything else (blank, a stage added later) | — | Shown, never hidden; extend the mapping |

¹ Stages of the **PRISM status API** (built in parallel; values agreed 2026-11-06). They are mapped now and become active when the API writes them; until then no file carries them. They are accepted as stage or outcome.

**Successful** (`IsSuccess`, measure `SuccessFileCount`):

| Direction / interface | Successful when |
|---|---|
| Inbound | Outcome FULLY_PROCESSED |
| Outbound, ACK expected (`ZCD_FMON_IFACE-ACK_EXPECTED` = X) | Outcome ACK_RECEIVED **and** NACK count 0 (a payment-level rejection after the ACK is not a success — FMON status rule 3) |
| Outbound, no ACK (BlackLine, GL OFSAA, cost centre, Stripe — `DEVELOPMENT_STANDARDS.md` §1) | Stage SENT_TO_PRISM, PRISM_RECEIVED, PRISM_DELIVERED, FORWARDED_TO_BANK or ACK_RECEIVED, and not NACK_REJECTED / PRISM_FAILED |
| Interface row missing (deleted / renamed) | Treated as ACK expected — success is never claimed without the evidence the interface would need |

**Cumulative "reached" measures** answer "how many were sent today" independently of the current bucket: `SentFileCount` (outbound reached SENT_TO_PRISM or later), `ProcessedFileCount` (inbound loaded or processed, not FAILED).

## 4. Measures and dimensions

| Measure (default aggregation SUM) | Source |
|---|---|
| Files, successful, per bucket (received, at PRISM, sent, processed, acknowledged, rejected, partial, unknown), files with unprocessed items, breached, late | Derived per file (1 / 0) |
| Records (`RecordCount`) — the "transactions" of a file | `ZCD_FMON_FILE-RECORD_COUNT` from the source row |
| Control total, ACK amount | `CONTROL_TOTAL`, `ACK_AMOUNT` |
| ACK count, NACK count, unprocessed items | `ACK_COUNT` (with `AckCountKnown`: blank = not reported, not zero), `NACK_COUNT`, `UNPROCESSED_COUNT` |
| Open exceptions | Open / assigned FMON findings of the file |

**Currency:** the file row stores no currency. Control totals are in the interface contract currency (USD for the current banks — confirm per interface in `Interface_Inventory.md`). Slice by interface before reading totals; never add totals of interfaces with different currencies.

Dimensions: interface (+ description, owner, target system, ACK expected / level), direction, file type, source system, LOB, payment method, **bank** (from the interface row — the file row carries no bank; blank = interface for any bank), business date, `IsToday` (business date = server date), stage, outcome, flow bucket, SLA status, worst severity.

## 5. SLA status — from the open exceptions of the file

> **First principle:** the dashboard does not judge SLAs itself — it shows the verdict the monitor already stored as an exception.
> **Analogy:** the departures board shows "delayed" because the tower said so, not because the board did the maths.

The FMON checks write file findings with `REFERENCE` = file ID in hex (`ZCL_CD_FMON_UTIL=>NEW_FINDING`). `ZI_CD_FmonFileExc` groups the **open** ones (disposition O open, A assigned; area FMON, object FILE) per file. The object key (file name, max 70 characters) is not used: identical daily file names are separate instances (audit A49).

| SLA status | Rule | Colour |
|---|---|---|
| NO_FINDINGS | No open exception on the file | green |
| BREACHED | An open `NO_<stage>` exception (SLA stage not reached in time: NO_PRISM_HANDOFF, NO_BANK_FORWARD, NO_BANK_ACK, NO_FILE_LOAD, NO_PROCESSING — `ZCL_CD_FMON_RULES=>SLA_CODE`) | red |
| LATE | No breach, an open `*_LATE` exception (FILE_LATE, PRISM_HANDOFF_LATE, BANK_ACK_LATE …) | yellow |
| OK | Open exceptions exist, none about the SLA (e.g. ACK_COUNT_MISMATCH, DUPLICATE_FILE) — see worst severity | green |

Resolved, waived, superseded and information findings never count. **Missing files** (FILE_MISSING, key `<interface>/<date>`) have no file row; they appear only in the open-exceptions entity (tile "Missing files").

## 6. Tiles, KPI and overview-page cards

All tiles are dynamic tiles on the service binding `ZUI_CD_FMON_FLOW_O4` (`/sap/opu/odata4/sap/zui_cd_fmon_flow_o4/srvd/sap/zui_cd_fmon_flow/0001/`; path confirmed when the binding is published — VERIFY-ADT). The count is OData `$count` with a filter; Fiori elements reads `@odata.count` / the `/$count` path.

| Tile | Entity / request | Red when |
|---|---|---|
| **Stale monitor** | `MonitorAsOf/$count?$filter=IsStale eq true` (0 or 1); info: `MonitorAsOf?$select=AgeMinutes` | ≥ 1 |
| Rejected today | `FileFlow/$count?$filter=IsToday eq true and FlowBucket eq 'REJECTED'` | ≥ 1 |
| Unprocessed | `FileFlow/$count?$filter=UnprocessedCount gt 0` | ≥ 1 |
| Breached SLA | `FileFlow/$count?$filter=SlaStatus eq 'BREACHED'` | ≥ 1 |
| Missing files | `OpenException/$count?$filter=CheckCode eq 'FILE_MISSING'` | ≥ 1 |
| File monitoring dashboard (app tile) | Semantic object `ZCDFileFlow`, action `analyze` → the analytical list page | — |

**KPI entity `FileFlowKpi`** (`ZC_CD_FmonFlowKpi`): one row per business date with the bucket counts, successful, rejected, partial, unprocessed files and items, breached / late, open exceptions, records, the as-of / age / stale fields and a day criticality (red: rejected or breached; yellow: partial, late or unprocessed). Selection variant `Today` (`IsToday = X`), chart `FilesByBucket`, data points `Files`, `Rejected`, `Unprocessed`, `Breached`, `MonitorAge` — ready for OVP KPI and analytical cards. A business date without any file has no row; the as-of entity still shows the monitor age.

**List entity `LatestFailure`** (`ZC_CD_FmonFlowFail`): rejected (incl. PRISM_FAILED), partial and SLA-breached files, newest last event first, presentation variant `maxItems` 10 — for an OVP list card or a list tile.

## 7. Drill-down path

File row → object page → **Events** (what each source said and when; `MANUAL` = manual-status app, `LOT` = derived from returns / NOC lots) → **Open exceptions** (what the monitor concluded) → owned-exceptions app to work them.

**Payment trace:** `ZCD_OPS_PAYMENT_TRACE` does not accept a file reference (`Payment_Trace.md` §8 — the reverse link file → payments needs the ZCDT_REGUT link confirmed first). Navigation from a file to the trace is therefore **proposed, not built**: intent `ZCDPaymentTrace-display` → transaction for report `ZCD_OPS_PAYMENT_TRACE` with parameter `FileRef`, once the trace accepts it. Until then L2 copies the file name and searches by FIN / document from the incident.

## 8. Coverage limit — what is not shown

- **Only interfaces with a row in `ZCD_FMON_IFACE`** are monitored. Everything marked *Gap* in `Interface_Inventory.md` (stop pay, cheque print file to IRIS, GL OFSAA, cost centre, CAMT, source-system files …) is invisible here — invisible is not healthy.
- **No live source counts.** The dashboard shows what the last monitor run stored, not the source tables now; a file written after the last run appears at the next run. A live view of source counts is **proposed later** (it would need bounded reads of every evidence table per request).
- Files that never reach an SAP evidence table (a file in a directory never loaded) are not seen (`Interface_Inventory.md` §2, limit 1).
- No payment-level detail: one row per file; payment-level ACKs are counted on the file (`ACK_COUNT`).

**Sensitive data.** Rows carry interface, file name / reference, counts and amounts — no member, account or bank-account data. File names are system-generated batch names matched by pattern (`config/fmon_seed.md`, e.g. `ACH_PNC_*`). Event information and source reference of a `MANUAL` event are operator text (reason, evidence reference) — the same exposure as the manual-status app; operators must not enter personal data there (runbook §4b).

## 9. Objects (package `ZCD_OPS_FMON`, `src/fmon`, read-only)

| Object | Type | Role |
|---|---|---|
| `ZI_CD_FmonFlowFile` | view entity (basic) | File + interface: bucket, success, measures, `FileIdHex` |
| `ZI_CD_FmonFileExc` | view entity (grouped) | Open FMON exceptions per file: count, breached, late, worst severity |
| `ZI_CD_FmonRunLast` | view entity (aggregate, one row) | End of the last completed full FMON run |
| `ZR_CD_FmonAsOf` / `ZC_CD_FmonAsOf` | root view / projection | As of, run, age, stale |
| `ZR_CD_FmonFlow` / `ZC_CD_FmonFlow` | root view / projection (`@Aggregation.default`) | Dashboard rows (file × as-of), SLA status, associations to events and open exceptions |
| `ZR_CD_FmonFlowEvt` / `ZC_CD_FmonFlowEvt` | root view / projection | File events (drill-down) |
| `ZR_CD_FmonFlowFind` / `ZC_CD_FmonFlowFind` | root view / projection | Open FMON exceptions (drill-down, missing files) |
| `ZR_CD_FmonFlowKpi` / `ZC_CD_FmonFlowKpi` | root view (grouped) / projection | KPI per business date (tiles, OVP) |
| `ZR_CD_FmonFlowFail` / `ZC_CD_FmonFlowFail` | root view / projection | Latest failures list |
| `ZC_CD_FMONFLOW`, `…EVT`, `…FIND`, `…KPI`, `…FAIL`, `ZC_CD_FMONASOF` | metadata extensions | UI: charts, presentation variants, selection fields, line items, facets, data points |
| `ZC_CD_FMONFLOW` | access control (DCL) | `pfcg_auth( ZCD_OPS, ZCD_PE_AREA, ACTVT = '03' )` on the six projections; every row carries `PaymentEngineArea` = FMON |
| `ZUI_CD_FMON_FLOW` | service definition | `FileFlow`, `FileEvent`, `OpenException`, `MonitorAsOf`, `FileFlowKpi`, `LatestFailure` |
| `ZUI_CD_FMON_FLOW_O4` | service binding (OData V4 – UI) | **Created in ADT** (the repository carries no bindings) |
| `ZCL_CD_FMON_FLOW_CDS_TEST` | class (test holder, no logic) | CDS unit tests (§11) |
| `cds/ZI_CD_FmonFlowCube`, `cds/ZC_CD_FmonFlowQry` | cube / analytical query (ADT, outside abapGit) | Analysis for Office / query browser; DCL grant in `ZI_CD_OpsAnalytics` |

Existing classes are unchanged. `tools/abapgit_serialize.py` now also writes DCLS metadata (`.dcls.xml`, fixture test `test_dcls_is_serialized`).

## 10. VERIFY-ADT (release-dependent, confirmed at activation on 7.58)

| Item | Where | Fallback if refused |
|---|---|---|
| `bintohex( )` in a view entity returns upper-case hex equal to `ZCL_CD_FMON_UTIL=>FILE_HEX` | `ZI_CD_FmonFlowFile` | Compare in the finding view with `hextobin( reference )` against `FILE_ID` |
| Aggregate without GROUP BY next to a literal element (one-row view) | `ZI_CD_FmonRunLast` | `group by pe_area`; then no row without a completed run — handle "no row" as stale in the tile |
| `CROSS JOIN` of the one-row as-of view in a root view entity | `ZR_CD_FmonFlow` | Drop the as-of fields from the rows; header KPI from `MonitorAsOf` only |
| `sum( case … )`, `max( case … )`, `left( )`, `right( rtrim( ) )` on CHAR | `ZI_CD_FmonFileExc`, `ZR_CD_FmonFlowFind` | Flag columns in a non-grouped view, then sum |
| TIMESTAMPL → TIMESTAMP cast and `tstmp_seconds_between` / `tstmp_current_utctimestamp` | `ZR_CD_FmonAsOf` (as `ZI_CD_OpsRun`) | `tstmpl_to_utcl` + `utcl_seconds_between( utcl_current( ) )` |
| OData V4 data aggregation (`$apply`) of a `transactional_query` projection without behaviour definition | `ZC_CD_FmonFlow`, `ZC_CD_FmonFlowKpi` | Annotate `@ObjectModel.supportedCapabilities: [ #ANALYTICAL_PROVIDER ]` / expose the cube via an analytical service |
| `@UI.chart`, `@UI.presentationVariant`, `@UI.selectionVariant` (filter string) rendering in the V4 analytical list page and OVP | metadata extensions | Adjust in the app's annotation file of the Fiori project |
| `pfcg_auth` on a literal-valued element of a projection | DCL `ZC_CD_FMONFLOW` | `where ( ) = aspect pfcg_auth( ZCD_OPS, ZCD_PE_AREA = 'FMON', ACTVT = '03' )` |
| DCLS abapGit metadata (`DCLNAME`, `DESCRIPTION`) | `zc_cd_fmonflow.dcls.xml` | Create the role in ADT from the `.asdcls` source |
| `cl_cds_test_environment=>create( i_select_base_dependencies = abap_true )` and `create_for_multiple_cds` doubling the tables behind the stack | test include | Double the first-level views and insert view rows instead |

## 11. Tests

ABAP Unit in `ZCL_CD_FMON_FLOW_CDS_TEST` (test include; `cl_cds_test_environment` doubles of ZCD_FMON_FILE, ZCD_FMON_IFACE, ZCD_OPS_FINDING, ZCD_OPS_RUN; not executed offline):

| Class | Tests |
|---|---|
| `ltc_flow` (`ZR_CD_FMONFLOW`) | `bucket_maps_every_stage` (17 cases incl. the three PRISM stages and an unknown stage), `success_needs_ack_if_expected`, `success_on_delivery_no_ack`, `success_inbound_fully_only`, `success_unregistered_iface`, `measures_sum_per_source_lob`, `sla_breached_on_missing_stage`, `sla_late_on_late_finding`, `sla_ok_with_other_finding`, `sla_closed_findings_ignored`, `breached_wins_over_late`, `rows_carry_monitor_as_of` |
| `ltc_as_of` (`ZR_CD_FMONASOF`) | `as_of_skips_running_and_abort`, `as_of_skips_test_and_iface_run`, `stale_when_no_completed_run`, `stale_when_run_is_old`, `fresh_run_is_not_stale` |
| `ltc_kpi` (`ZR_CD_FMONFLOWKPI`, `ZR_CD_FMONFLOWFAIL`) | `kpi_counts_buckets_per_day`, `failures_list_bad_files_only` |

The DCL is not covered by the unit tests (they select the `ZR_` views); QA case FMD-08 covers it.

## 12. QA1 cases

| ID | Case | Expected |
|---|---|---|
| FMD-01 | Run `ZCD_FMON_MONITOR` (test mode off), open the dashboard | As of = end of that run; age < 30 min; not stale |
| FMD-02 | Stop the SM36 job for > 15 min (or look at QA1 without runs) | Header and every row: stale, red; tile *Stale monitor* = 1 — the page never looks like a quiet day |
| FMD-03 | Run the monitor for one interface only, and in test mode | As of does not move |
| FMD-04 | Outbound ACH file: generated → sent → ACK | Bucket RECEIVED → SENT → ACKNOWLEDGED across runs; successful only after the ACK; SE16 ZCD_FMON_FILE matches |
| FMD-05 | BlackLine file (no ACK) sent to PRISM | Bucket SENT, successful |
| FMD-06 | Returns file with open lot items | PARTIAL, unprocessed items = open items; tile *Unprocessed* counts it; listed in *Latest failures* |
| FMD-07 | File with an open NO_BANK_ACK exception, then resolve it in the exceptions app and re-run | SLA BREACHED (red) → NO_FINDINGS |
| FMD-08 | User with ZCD_OPS ZCD_PE_AREA = HCK only | No rows in any entity (DCL); with FMON / 03: rows visible |
| FMD-09 | Filter source PCLM, LOB, payment method ACH, bank PNC, business date today | Chart and table restricted; totals equal SE16 sums on ZCD_FMON_FILE for the same filter (with the interface → bank mapping) |
| FMD-10 | Drill to a file → events → open exceptions | Events equal ZCD_FMON_EVENT for the file ID; exceptions equal the open ZCD_OPS_FINDING rows with that reference |
| FMD-11 | Expected file not received (FILE_MISSING) | Not a file row; tile *Missing files* = 1; listed under OpenException |
| FMD-12 | ST05 while using the page, tiles and drill-down | SELECT only on ZCD_FMON_FILE / _IFACE / _EVENT, ZCD_OPS_FINDING / _RUN; no write, no lock, no job, no business table read |
| FMD-13 | When the PRISM status API ships: a file with PRISM_RECEIVED, PRISM_DELIVERED, PRISM_FAILED | Buckets AT_PRISM, SENT (out) / RECEIVED (in), REJECTED |

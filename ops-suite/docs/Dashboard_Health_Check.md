# Health check dashboard — morning report RAG, scorecard, warm-up, metric trends

> **First principle:** a check is green only when it ran in the last completed morning report and found nothing — a check that did not run, or whose baseline is still learning, is shown as such, never as green.
> **Analogy:** a pilot's pre-flight checklist on a board — every item ticked, flagged or "not yet checked", with the time the checklist was last completed; an old checklist is a reason not to take off.

Status 2026-11-06: written and statically checked offline (abaplint: CDS parsed, ABAP checked, 0 issues). **Not activated in SAP, ABAP Unit not executed** — the first DV1 import is the test. Same pattern as `Dashboard_File_Monitoring.md`; one of the four area dashboards of `Dashboard_Production_Support.md`.

## 1. What the support team sees

Fiori elements **analytical list page** (OData V4, service `ZUI_CD_HCK_DASH`, main entity `HealthCheck`); read-only. Exceptions are worked in the owned-exceptions app.

| Area | Content |
|---|---|
| Header / KPI | **Morning report as of** (end of the last completed run), age, stale (red when older than 26 hours or no completed run), overall RAG of that run |
| Filter bar | Category, priority, check, status in the last run |
| Chart (default) | Checks by **category**, stacked by status (red, amber, green, warm-up, no result). Alternative: open exceptions (red / amber) by category and check |
| Table | One row per active check (`ZCD_HCK_DEF`): category, check, text, priority, status (coloured), open exceptions, oldest due date, metric rows of the run |
| Object page | Check attributes, last-run counts, open exceptions, as of; **Metric history** (31 days, one row per run × metric × DIM1 × DIM2) → **findings** of the check; **Findings** |
| Entity `HealthCategory` | **Scorecard**: one row per category with category status and check counts; drill → checks |
| Entity `HealthRun` | **Trend**: runs of 31 days — overall RAG, checks red / amber / green / warm-up per run date, run message (health score) |
| Entity `MetricHistory` | **Metric trend** chart: value per day, one line per **DIM2** series |

## 2. Freshness

- The dashboard reads what the morning report (`ZCD_MORNING_REPORT`, `ZCL_CD_HCK_ENGINE`) stored: `ZCA_OPS_RUN`, **`ZCD_HCK_RESULT`** (verdict of each check per run, design review 2026-11-07), `ZCA_OPS_FINDING` (area HCK, object CHECK - open exceptions, findings), `ZCD_HCK_METRIC` (history). It runs no check and derives no status.
- **As of** = `ENDED_AT` of the last **completed** HCK run: not test mode, status S, W or E (GREEN closes S, AMBER W, RED and unrated E — A60). Running (R) and aborted (A — incl. a run refused because another held the lock, `ZCL_CA_OPS_RUN_GUARD`) runs never move it. Any report variant.
- **Stale** after the parameter `MON_STALE_AFTER_MIN_<area>` (ZCA_PARAM area `CD_OPS`: value row, else definition default, read through `ZI_CD_OpsStaleCfg`; was the `ZCD_OPS_MONCFG` row until the table consolidation of 2026-11-08; the morning report self-check reads the same parameter) or when there is no completed run; without a definition **26 hours** (`HCK_MAX_AGE_HOURS` default; fallback literal in `ZR_CD_HckAsOf`, portable check `cds_abap_parity`). Delivered definition default HCK = 1560. `AgeMinutes` and `StaleAfterMinutes` exposed.

## 3. Status of a check (last completed run)

**Design review 2026-11-07: the status is persisted, not inferred.** The engine writes one `ZCD_HCK_RESULT` row per executed check and run from the same decision the report uses (`ZCL_CD_HCK_ENGINE->RESULT_ROW` after `FINALIZE_RESULT`); the dashboard shows that row (`ZI_CD_HckResult`). Dashboard and report can no longer differ (the former inference made a warm-up next to a fixed green limit WARMUP, a check without metric and finding NO_RESULT).

| Status (`ZCD_HCK_RESULT-CHECK_STATUS` of the as-of run) | Meaning | Colour |
|---|---|---|
| RED | Verdict R (finding B / E, red threshold, …) | red |
| FAILED | The plug-in failed (PLUGIN_ERROR): completion FAILED, evidence NONE - counted red, **never green** | red |
| AMBER | Verdict A | yellow |
| GREEN | Verdict G - also a check without any metric or finding, and a warm-up next to a fixed limit the value passes (as in the report) | green |
| WARMUP | Baseline-only metric still warming up (A102), grey verdict | grey |
| GREY | No verdict for another reason | grey |
| SKIPPED | Active check outside the scope of a filtered run (category / priority / check filter); the scope is shown | grey |
| NO_RESULT | No row in the as-of run (e.g. a check activated after it) | grey |

Shown with the status: **completion** (COMPLETE / PARTIAL - timeout, time budget, capped read / FAILED / SKIPPED), **evidence** (ALL / PARTIAL - e.g. a mandatory in-flight evidence kind not usable / NONE), **scope of the run** (variant, categories, priorities, check ids), **baseline mode** used (NONE / ZSCORE / IQR / MIXED), summary and execution time. The **overall RAG** and the **health score** stay those the engine stored: RAG in `ZCA_OPS_RUN-RAG`, score and critical / high counts in the run message (`HealthKpi-RunMessage`, `HealthRun`). **Open exceptions** per check count every open / assigned HCK finding, whatever run raised it (an exception of an older run is still open; it does not change today's status). Category status = worst check of the category (RED, AMBER, GREEN; GREY when no check has a verdict).

Category texts (A financial integrity, B mass-run and job health, C exception queues, D configuration drift, E technical health) are CDS literals = `HCK_MORNING_REPORT.md` §1.

## 4. Tiles, KPI and overview-page cards

Service binding `ZUI_CD_HCK_DASH_O4` (path VERIFY-ADT).

| Tile | Request | Red when |
|---|---|---|
| **Stale morning report** | `ReportAsOf/$count?$filter=IsStale eq true` | ≥ 1 |
| Red checks | `RedCheck/$count?$filter=CheckStatus eq 'RED'` | ≥ 1 |
| Overdue exceptions | `HealthKpi?$select=OverdueCount` | > 0 |
| Health check dashboard (app tile) | Semantic object `ZCDHealthCheck`, action `analyze` | — |

**KPI entity `HealthKpi`** (`ZC_CD_HckKpi`, one row): overall RAG (data point `OverallRag`), run message, age / stale, checks / green / amber / red / warm-up (data points `RedChecks`, `AmberChecks`), open exceptions total / red / amber / overdue (`Overdue`). **List entity `RedCheck`** (`ZC_CD_HckRed`): red and amber checks of the last run, red first, `maxItems` 10.

## 5. Drill-down path

`HealthCategory` → checks → `HealthCheck` object page → **metric history** (DIM1 = company code / job / source, DIM2 = series) → findings of the check; `HealthRun` → findings of the run. The cds/ analytics views (`ZI_CD_HckMetric`, `ZI_CD_HckMetricCube`, `ZC_CD_HckMetricQry`) stay for Analysis for Office; the OData V4 views are separate src/ views so the abapGit pull never depends on cds/ objects.

## 6. Limits

- Metric history, runs and closed findings: **31 days**. Open findings: always.
- `MetricValue` aggregates as **MAX** in charts (highest measurement of the group) — for volumes per day with one run a day this is the value; use `cds/ZC_CD_HckMetricQry` for SUM / weighted rates (A88).
- Checks deleted from `ZCD_HCK_DEF` disappear from `HealthCheck`; their findings remain in `HealthFinding`.
- No business data is read; messages are the engine's texts (no member or account data in HCK messages).

## 7. Objects (package `ZCD_OPS_HCK`, `src/hck`, read-only)

| Object | Type | Role |
|---|---|---|
| `ZI_CD_HckRunLast` | view (one row) | End of the last completed HCK run |
| `ZI_CD_HckFinding`, `ZI_CD_HckCheckOpen`, `ZI_CD_HckOpenSum` | views | Findings (bounded); open per check; open now (one row) |
| `ZI_CD_HckResult` | view | Persisted verdict per run × check (`ZCD_HCK_RESULT`; replaces the inference views `ZI_CD_HckCheckRes` / `ZI_CD_HckRunMetric`, removed 2026-11-07) |
| `ZI_CD_HckMetricBase` | view | Metric history of 31 days |
| `ZR_CD_HckAsOf` / `ZC_` | root / projection | As of, RAG, check counters, message, age, stale |
| `ZR_CD_HckCheck` / `ZC_` | root / projection (ALP) | Check × last run status, open exceptions, as of |
| `ZR_CD_HckCategory`, `ZR_CD_HckRun`, `ZR_CD_HckMetric`, `ZR_CD_HckFind` (+ `ZC_`) | roots / projections | Scorecard, trend, metric history, findings |
| `ZR_CD_HckKpi`, `ZR_CD_HckRed` (+ `ZC_`) | roots / projections | KPI (one row), red / amber checks |
| 8 metadata extensions `ZC_CD_HCK*` | DDLX | UI |
| `ZC_CD_HCKDASH` | DCL | `pfcg_auth( ZCD_OPS, ZCD_PE_AREA, ACTVT = '03' )`, rows carry HCK |
| `ZUI_CD_HCK_DASH` | service definition | `HealthCheck`, `HealthCategory`, `HealthRun`, `MetricHistory`, `HealthFinding`, `ReportAsOf`, `HealthKpi`, `RedCheck` |
| `ZCL_CD_HCK_DASH_CDS_TEST` | class (test holder) | CDS unit tests (§9) |

## 8. VERIFY-ADT

| Item | Where | Fallback |
|---|---|---|
| LEFT OUTER JOIN conditions on fields of a cross-joined row | `ZR_CD_HckCheck` | Join `ZI_CD_HckResult` to `ZI_CD_HckRunLast` first (run of the as-of) and join that view |
| `cast( group2 as abap.char( 20 ) )` (shorter CHAR) | `ZI_CD_HckFinding` | Compare CHAR 35 with CHAR 20 directly |
| Aggregate without GROUP BY (one row, also on an empty set) | `ZI_CD_HckOpenSum`, `ZI_CD_HckRunLast` | `group by` a literal-valued element; no row = zero in the tile |
| GROUP BY over a root view with associations | `ZR_CD_HckCategory` | Select from the non-root base views instead |
| `$apply` on transactional_query projections; UI.chart / OVP rendering | projections, DDLX | As `Dashboard_File_Monitoring.md` §10 |

## 9. Tests

`ZCL_CD_HCK_DASH_CDS_TEST` (doubles of ZCD_HCK_DEF, ZCD_HCK_RESULT, ZCD_HCK_METRIC, ZCA_OPS_FINDING, ZCA_OPS_RUN):

| Class | Tests |
|---|---|
| `ltc_check` (`ZR_CD_HCKCHECK`, `ZR_CD_HCKCATEGORY`, `ZR_CD_HCKKPI`) | `status_of_every_check`, `old_run_finding_stays_open`, `category_takes_worst_check`, `kpi_counts_open_exceptions` |
| `ltc_verdict` (`ZR_CD_HCKCHECK`, design review 2026-11-07) | `green_without_metric_green`, `filtered_run_shows_scope`, `warmup_fixed_limit_report`, `failed_check_never_green` |
| `ltc_history` (`ZR_CD_HCKASOF`, `ZR_CD_HCKMETRIC`) | `stale_without_completed_run`, `moncfg_threshold_applies`, `history_keeps_dim2_series` |

## 10. QA1 cases

| ID | Case | Expected |
|---|---|---|
| HCD-01 | Productive morning report run, open the dashboard | As of = end of the run; overall RAG = report mail; status per check = report ALP lights |
| HCD-02 | No run for > 26 h; then a test-mode run | Stale (red) in both cases; tile *Stale morning report* = 1 |
| HCD-03 | Check with a red threshold | RED; finding listed; scorecard category RED |
| HCD-04 | New baseline-only check (fewer than 3 runs) | WARMUP; not counted as green in the scorecard |
| HCD-05 | Report variant restricted to category B | Checks of other categories SKIPPED with the run scope shown (not green) |
| HCD-06 | Resolve an older exception of a green check | Open count drops; status unchanged |
| HCD-07 | `B_VOLUME` with DIM2 per payment method | Metric history chart: one line per DIM2 series; values equal ZCD_HCK_METRIC |
| HCD-08 | User without ZCD_OPS HCK / 03 | No rows |
| HCD-09 | ST05 | SELECT only on ZCA_OPS_RUN / _FINDING, ZCD_HCK_DEF / _RESULT / _METRIC |
| HCD-10 | Check that ran green without a metric (e.g. no open exception queue) | GREEN, metric rows 0 - same as the report mail |
| HCD-11 | Baseline check in warm-up next to a fixed limit the value passes | GREEN on the dashboard and in the report; baseline mode ZSCORE shown |
| HCD-12 | Check class that raises (test client) | FAILED, completion FAILED, evidence NONE; counted red, never green |

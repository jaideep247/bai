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

- The dashboard reads what the morning report (`ZCD_MORNING_REPORT`, `ZCL_CD_HCK_ENGINE`) stored: `ZCD_OPS_RUN`, `ZCD_OPS_FINDING` (area HCK, object CHECK), `ZCD_HCK_METRIC`. It runs no check.
- **As of** = `ENDED_AT` of the last **completed** HCK run: not test mode, status S, W or E (GREEN closes S, AMBER W, RED and unrated E — A60). Running (R) and aborted (A — incl. a run refused because another held the lock, `ZCL_CD_OPS_RUN_GUARD`) runs never move it. Any report variant.
- **Stale** after `STALE_AFTER_MIN` of the `ZCD_OPS_MONCFG` row of the area (configuration app *Alerting and parameters*, entity *Monitor freshness*; the morning report self-check reads the same row) or when there is no completed run; without a row **26 hours** (`HCK_MAX_AGE_HOURS` default; fallback literal in `ZR_CD_HckAsOf`, portable check `cds_abap_parity`). Delivered row HCK = 1560. `AgeMinutes` and `StaleAfterMinutes` exposed.

## 3. Status of a check (last completed run)

| Status | Rule (findings and metric rows **of the as-of run**) | Colour |
|---|---|---|
| RED | A finding of severity B or E (THRESHOLD_RED, PLUGIN_ERROR, STEP_FAILED …) | red |
| AMBER | A finding of severity W (THRESHOLD_AMBER, BASELINE_OUTLIER, TIMEOUT_OVERRUN …) | yellow |
| WARMUP | Only BASELINE_WARMUP information (A102: fewer than 3 history points) | grey |
| GREEN | Ran: metric rows, or only information findings (e.g. suppressed), and no B / E / W | green |
| NO_RESULT | No metric row and no finding in the run — not selected by the run's variant (category / check filter) or a check that measures nothing | grey |

The **overall RAG** and the **health score** stay those the engine stored: RAG in `ZCD_OPS_RUN-RAG`, score and critical / high counts in the run message (`HealthKpi-RunMessage`, `HealthRun`). The dashboard does not recompute the score (it needs per-check priority weights of checks that ran green without metrics). Per-check status is derived from the run's findings and can differ from the report in one case: a warm-up check that also has a static green limit is GREEN in the report and WARMUP here. **Open exceptions** per check count every open / assigned HCK finding, whatever run raised it (an exception of an older run is still open; it does not change today's status). Category status = worst check of the category (RED, AMBER, GREEN; GREY when no check has a verdict).

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
| `ZI_CD_HckFinding`, `ZI_CD_HckCheckRes`, `ZI_CD_HckCheckOpen`, `ZI_CD_HckOpenSum` | views | Findings (bounded); result per run × check; open per check; open now (one row) |
| `ZI_CD_HckMetricBase`, `ZI_CD_HckRunMetric` | views | Metric history of 31 days; metric rows per run × check |
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
| LEFT OUTER JOIN conditions on fields of a cross-joined row | `ZR_CD_HckCheck` | Join `ZI_CD_HckCheckRes` to `ZI_CD_HckRunLast` first (run of the as-of) and join that view |
| `cast( group2 as abap.char( 20 ) )` (shorter CHAR) | `ZI_CD_HckFinding` | Compare CHAR 35 with CHAR 20 directly |
| Aggregate without GROUP BY (one row, also on an empty set) | `ZI_CD_HckOpenSum`, `ZI_CD_HckRunLast` | `group by` a literal-valued element; no row = zero in the tile |
| GROUP BY over a root view with associations | `ZR_CD_HckCategory` | Select from the non-root base views instead |
| `$apply` on transactional_query projections; UI.chart / OVP rendering | projections, DDLX | As `Dashboard_File_Monitoring.md` §10 |

## 9. Tests

`ZCL_CD_HCK_DASH_CDS_TEST` (doubles of ZCD_HCK_DEF, ZCD_HCK_METRIC, ZCD_OPS_FINDING, ZCD_OPS_RUN):

| Class | Tests |
|---|---|
| `ltc_check` (`ZR_CD_HCKCHECK`, `ZR_CD_HCKCATEGORY`, `ZR_CD_HCKKPI`) | `status_of_every_check`, `old_run_finding_stays_open`, `category_takes_worst_check`, `kpi_counts_open_exceptions` |
| `ltc_history` (`ZR_CD_HCKASOF`, `ZR_CD_HCKMETRIC`) | `stale_without_completed_run`, `history_keeps_dim2_series` |

## 10. QA1 cases

| ID | Case | Expected |
|---|---|---|
| HCD-01 | Productive morning report run, open the dashboard | As of = end of the run; overall RAG = report mail; status per check = report ALP lights |
| HCD-02 | No run for > 26 h; then a test-mode run | Stale (red) in both cases; tile *Stale morning report* = 1 |
| HCD-03 | Check with a red threshold | RED; finding listed; scorecard category RED |
| HCD-04 | New baseline-only check (fewer than 3 runs) | WARMUP; not counted as green in the scorecard |
| HCD-05 | Report variant restricted to category B | Checks of other categories NO_RESULT (not green) |
| HCD-06 | Resolve an older exception of a green check | Open count drops; status unchanged |
| HCD-07 | `B_VOLUME` with DIM2 per payment method | Metric history chart: one line per DIM2 series; values equal ZCD_HCK_METRIC |
| HCD-08 | User without ZCD_OPS HCK / 03 | No rows |
| HCD-09 | ST05 | SELECT only on ZCD_OPS_RUN / _FINDING, ZCD_HCK_DEF / _METRIC |

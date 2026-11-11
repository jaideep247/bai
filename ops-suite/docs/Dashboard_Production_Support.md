# Production support overview page and launchpad space

> **First principle:** support starts every shift from one page that says, per area, "is the monitor alive, and is anything red" — and each card opens the dashboard that proves it.
> **Analogy:** a hospital ward's nurses' station board — one row per patient (area) with vital signs and a red light, the board shows when each reading was taken, and a tap on a row opens the full chart.

Status 2026-11-11: **SAP job failures** cards added (KPI *Job failures today*, list *Job failures - today*; framework board `ZUI_CA_OPS_JOBS`, area `CD_JOBS`). Status 2026-11-10: **control center** added (daily controls with sign-off, payment lifecycle, open reconciliation variances, business-date filter - §1a). Status 2026-11-06: CDS and service written and statically checked offline (abaplint 0 issues); **not activated, ABAP Unit not executed**. The overview page app (manifest) and every launchpad object (space, pages, catalogs, tiles, target mappings, roles) are **documentation only** — the repository carries no FLP or UI5 objects; they are created in the target system (step 1f of `Implementation_Order.md`).

## 1. The page

Fiori elements **overview page (OVP)**, OData V4, one data source: service `ZUI_CD_OPS_OVERVIEW` (binding `ZUI_CD_OPS_OVERVIEW_O4`). Read-only.

| Card | Card type | Entity (overview service) | Shows | Navigates to |
|---|---|---|---|---|
| **Monitor freshness** | List (table) | `MonitorFreshness` | FMON, EBS, HCK: end of the last completed run, age, threshold; **CORE (2026-11-08): the payment outcome snapshot lag** - processed up to (`AsOfAt`), lag in minutes (`AgeMinutes`), threshold `MON_STALE_AFTER_MIN_CORE` (30), last snapshot run and its status; (ZCA_PARAM `MON_STALE_AFTER_MIN_<area>`, delivered 15 min / 26 h / 26 h; the same parameter the morning report self-check uses - was `ZCD_OPS_MONCFG`), **stale** (red) | The area's dashboard (row) / `ZCDFileFlow-analyze` (card header) |
| **Open critical exceptions** | List | `CriticalException` (selection variant `Overdue` as tab) | Open / assigned B and E findings of every area, overdue first: area, check code, object, owner, due date, days overdue | Owned-exceptions app (`ZCDOpsException-manage`, `ZUI_CD_OPS_EXC_O4`) |
| **Files** | KPI + analytical | `FileFlowKpi` (variant `Today`, chart `FilesByBucket`, data points `Rejected`, `Unprocessed`, `Breached`, `MonitorAge`) | Files per flow bucket today, rejected / unprocessed / breached | `ZCDFileFlow-analyze` (file monitoring ALP) |
| Files – latest failures | List | `FileFailure` | Rejected, partial, SLA-breached files | `ZCDFileFlow-analyze` |
| **EBS** | KPI + analytical | `EbsKpi` (variant `Latest`, chart `LinesByOutcome`, data points `Failed`, `Blocked`, `Unevaluated`, `PostingIncomplete`, `ValidationAge`) | Lines by outcome of the last run, not evaluated, POSTING_INCOMPLETE | `ZCDEbsValidation-analyze` |
| EBS – latest problems | List | `EbsProblem` | Open B / E findings, POSTING_INCOMPLETE | `ZCDEbsValidation-analyze` |
| **Health checks** | KPI | `HealthKpi` (data points `OverallRag`, `RedChecks`, `AmberChecks`, `Overdue`, `ReportAge`) | Overall RAG of the last morning report, red / amber checks, overdue exceptions, health-score text | `ZCDHealthCheck-analyze` |
| Health checks – reds | List | `HealthRedCheck` | Red and amber checks of the last run | `ZCDHealthCheck-analyze` |
| **Transactions** | Analytical + KPI | `TransactionKpi` (chart `Worklist`, variant `Today`, data points `Entries`, `Open`, `Exceptions`, `RequestsNotPaid`) | The payment worklist per worklist date (exceptions-only, 2026-11-08): open payments and requests, exceptions, late payments, requests not paid on their due date - clean payments are not counted | `ZCDTransaction-analyze` |
| Transactions – errored / stuck | List | `TransactionProblem` | The worklist's exceptions: inconsistent, undetermined, ambiguous, late beyond AMBER / RED, waiting for the status job, requests not paid on their due date | `ZCDTransaction-analyze` (row: `ZCDPaymentTrace-display`, proposed) |
| **Checks reviewed** (control center) | KPI | `ControlDay` (data point `ChecksReviewed` = reviewed of `ControlCount`; `AwaitingReview`, `ReviewOverdue`) | *Checks reviewed n / m (k awaiting review)* for the business date | Review app *Daily control review* (`ZCAControlReview-manage`) |
| **Controls flagged** (control center) | KPI | `ControlDay` (data point `ControlsFlagged`; `ActionRequired`, `Watch`) | *Controls flagged n (a require action, w on watch)* | Review app, filter *Flagged* |
| **Open variances** (control center) | KPI + list | `ReconVariance` (data point `OpenVariances`, selection variant `Unresolved`; variant `Timing` = classified as timing) | Group-days of the three-way reconciliation with a difference beyond tolerance on the business date: expected, SAP actual, variance, disposition | Exceptions app filtered by area CD_HCK (classify TIMING / INVESTIGATING or resolve there); `ZCDHealthCheck-analyze` |
| **Daily health checks** (control center) | List (table) | `ControlDay` (presentation variant `DailyChecks`) | Control, category, status (Healthy / Watch / Action required, coloured), owner + team, exceptions, awaiting review; "View all controls" | Review app (row: the control and date) |
| **Payment lifecycle** (control center) | Analytical (bars) | `PaymentLifecycle` (chart `Lifecycle`, sorted by the configured stage order) | Tracked payments of the business date per stage (PENDING ... STOPPED, `ZCD_OPS_PAYSTAGE`; the request-status stages PENDING / SCHEDULED / SRCREJECT / SRCPOSTED inactive until the status field is named) | "View payments": `PaymentOfDay` list (payment reference → payment trace) |
| **Attention queue** (control center) | List | `ControlDay` (selection variant `Flagged`, presentation variant `Attention`) | Controls with Action required / Watch, open exceptions, awaiting review; "Review queue" | Exceptions app filtered by the control's area; review app |
| **Business processes** (process onboarding, 2026-11-10) | KPI | `ProcessCheck` (framework projection `ZC_CA_OpsCheckStatus`; data points `ProcessChecks` = registered checks, `ChecksFlagged` = check / company-code slices with an open exception, `ChecksStale` = no completed run within `CHECK_STALE_MIN_<area>` (else `CHECK_STALE_MIN_DEFAULT`) minutes, `OpenExceptions`) | *n registered checks - f flagged, s stale, e open exceptions* for every business process onboarded through the framework's check registry (e.g. `CD_COLL` / `BASE_REQ_LIFE` once active); empty until a process is active | Area dashboard (`ZCAOpsDashboard-display` → `ZUI_CA_OPS_DASH_O4`) |
| **Process checks - attention** (process onboarding) | List | `ProcessCheck` (selection variant `Attention` = open exception or stale; presentation variant `Attention`: worst status, then stale, then most open exceptions; 10 rows) | Process, check, company code, status (coloured), open exceptions, stale, last run | Area dashboard (row: the check); exceptions app filtered by area |
| **Job failures today** (SAP job monitor, area `CD_JOBS`, 2026-11-11) | KPI | `JobFailure` (framework projection `ZC_CA_OpsJobFailure`; selection variant `Today`; data points `FailuresToday`, `AbortedToday`, `ChildFailedToday` = a child failed while its parent / root - the job Control-M saw - finished, `NotStartedToday`, `LongRunningToday`; sums after the DCL) | *n job failures today - a cancelled, c child failed while the parent finished, s not started, l long-running* (server date of detection) | Board *SAP job failures* (`ZCAJobFailure-display` → `ZUI_CA_OPS_JOBS_O4`) |
| **Job failures - today** (list) | List | `JobFailure` (selection variant `Today`, presentation variant `Today`: errors first, newest first; 10 rows) | Job, check code (coloured), root job, Control-M job | Board (row: the job's object page - steps, job log errors, application logs, parent / children, business objects, exception) |
| Requests (after SE11) | Analytical | `PaymentRequest` of `cds/ZUI_CD_TRX_REQ` (second data source, §2; parameterised: request date window, as of) | Requested → processed → posted → paid → acknowledged → cleared; errored | Request funnel app |

Global filter: none mandatory (the area entities have different dimensions); each card applies its own selection variant. The page is as fresh as its sources: three cards read monitor runs (the freshness card says how old), the transactions cards are live.

### 1a. Control center (2026-11-10) - business date, time zone, no incidents

**Business date selection (decision).** The control center cards share the global filter fields `IsCurrentDay` and `BusinessDate` (OVP V4 global filter bar: `globalFilterEntitySet` = `ControlDay`, filter fields of the same name on every control center entity). **Default: `IsCurrentDay` = X** (`@Consumption.filter.defaultValue`), which the server computes as *today in the time zone of `CONTROL_TIME_ZONE`* (ZCA_PARAM area `CA_OPS`, value row `CST` = America/Chicago, `ZI_CA_OpsBusDay`) - not the browser's date, so a user in another time zone sees the Chicago business date. To look at another day the user clears *Current business date* and picks a **business date** (any of the last 31 days). CDS parameters are **not** used: OVP V4 cards on parameterised entity sets are release-dependent (VERIFY-ADT) and RAP BOs (the review app) cannot have parameters; a plain filter element works for every card and for the dynamic tiles (`$filter=IsCurrentDay eq true`). The older cards (freshness, critical exceptions, area KPIs) have no business date and ignore the filter.

| Card | Rule (all live, nothing copied) |
|---|---|
| Checks reviewed / awaiting / overdue | Framework daily control review (`ops-framework/docs/CONTROL_REVIEW.md`): one row per active control of the suite's areas and business date (`ZR_CA_OpsCtlReview` → `ZR_CD_OpsCtlDay`). **Status** = worst live finding of the control's checks on the date (B / E *Action required*, W *Watch*, else *Healthy*; resolved / waived findings and information findings do not count - so the latest result of the date decides, e.g. a health check that turned green in a later run). **Awaiting review** = no sign-off, or status now worse than at the sign-off, or a finding after the sign-off. **Overdue** = awaiting and past the control's cut-off (local time) or the date is over |
| Controls flagged | Watch + action required (counters of the same rows) |
| Open variances | `A_RECON_3WAY` metrics already stored (`ZCD_HCK_METRIC`): the latest measurement of each group-day and leg (bank ↔ G/L, G/L ↔ subledger) whose difference exceeds the tolerance the check used; expected / SAP actual / variance = actual − expected; **disposition from the exception workflow** - the reason code of the break exception (*Classify* in the exceptions app: TIMING, INVESTIGATING), TIMING when the check itself classified the day (`RECON_TIMING`), RESOLVED / WAIVED, OPEN, UNCLASSIFIED (no finding). *Unresolved on selected date* = OPEN, UNCLASSIFIED or a reason other than TIMING; *Classified as timing* = TIMING |
| Payment lifecycle | Payments of the business date = DPAYH rows with run date LAUFD = the date, proposal runs excluded, the **newest** run row per payment document (a re-run payment counts once, on its newest run), per live `ZZ_PAYMENT_STATUS`; request stages from the current request rows of the worklist due on the date. Stage order, labels and the value each stage counts are rows of `ZCD_OPS_PAYSTAGE` (core configuration app; `config/pay_stages.csv`); a stage without payments shows no bar. Access path: `Performance_Review.md` §11 |
| View payments | `PaymentOfDay`: payment reference (payment document), request source (from the worklist row when there is one; a clean payment has none - the trace shows it), company code, method, house bank, status, stage, amount; company-code authorisation on the row |

**No incidents in SAP (user decision 2026-11-10):** no incident card, no incident number or field anywhere; an *Action required* control carries an observation and a next action in its sign-off. No manual entry of payments or variances - SAP is the evidence.

### 1b. Company-code isolation (2026-11-10)

Every card that shows findings or counts them reads rows that carry a company code: the critical exceptions (company
code of the finding), the daily controls (one row per control, business date and company code - the framework's review
slices; blank = area-level slice), the variances (company code of the reconciliation group), the area cards (EBS run /
KPI slices, HCK check / KPI slices). The DCL `ZC_CD_OPSOVERVIEW` and the area DCLs apply the rule *area authorised AND
( company code blank OR ( area, company code ) authorised )*, so a KPI card of a user of company code 1000 sums the
area-level rows and the rows of 1000 only (`$apply` aggregates after the DCL). A central user sees one daily-control row
per control and date plus one per company code with findings; "checks reviewed n / m" counts slices
(`config/auth_zcd_ops.md` §3d, `ops-framework/docs/CONTROL_REVIEW.md` §2a). Freshness is area-level (runs only).

## 2. Design decision — one overview service (VERIFY-ADT for the alternative)

**Chosen: one service `ZUI_CD_OPS_OVERVIEW`** that re-exposes the KPI and latest-problem projections of the four area dashboards (the same CDS objects as in the area services, the same DCL roles) and adds two cross-area entities (`ZC_CD_OpsCritExc`, `ZC_CD_OpsFreshness`).

Why: (1) the OVP needs one model per card; with one service every card uses the default model, one `$metadata`, one binding to publish and one `S_SERVICE` per role; (2) no CDS is duplicated — exposing a projection in two service definitions is supported; (3) authorisation stays per area (each projection keeps its role), so a user sees only the cards' rows of the areas he may display; (4) the cross-area cards (critical exceptions, freshness) need a home anyway.

Alternative: an OVP over the four area services as separate data sources (`dataSources` in the manifest, `model` per card). OVP supports several models, but mixed-model V4 cards, global filter and navigation across models are release-dependent — **VERIFY-ADT** on the target UI5 version. It is used only for the cds/ request funnel (`ZUI_CD_TRX_REQ`), which must stay out of the abapGit service: added as a second data source with one card when part B of the transactions dashboard is activated. If the second model is not supported, the "Requests" card is replaced by a tile on the Transactions page (§4).

## 3. Cross-area entities

| Entity | CDS | Rule |
|---|---|---|
| `MonitorFreshness` | `ZR_CD_OpsFreshness` over `ZI_CD_OpsFreshU` (UNION of `ZR_CD_FmonAsOf`, `ZR_CD_EbsAsOf`, `ZR_CD_HckAsOf` and, since 2026-11-08, `ZI_CD_PayOutLag` - row CORE: minutes since the oldest `ZCD_PAY_OUTWM-CURRENT_TO` of the FAST evidence sources, recheck and NIGHTLY cursors left out; never run = stale) | One row per batch monitor; each area's completion rule and threshold (FMON: full run, variant ALL, 15 min; EBS: any variant, S/W/E/N, 26 h; HCK: S/W/E, 26 h); no completed run = stale. Transactions: open payments, requests and exceptions come from the payment worklist written by the 5-minute FAST snapshot (CORE run variant `PAY_OUTCOME`); its freshness is the CORE row (stale after `MON_STALE_AFTER_MIN_CORE`, 30 min; `Operations_Runbook.md` §5n) |
| `CriticalException` | `ZR_CD_OpsCritExc` over `ZCA_OPS_FINDING` | Disposition O / A, severity B / E, all areas; GROUP1 never exposed; EBS bank-file statement messages hidden; `DaysOverdue` = today − due date |

DCL `ZC_CD_OPSOVERVIEW`: `pfcg_auth( ZCA_OPS, ZCA_PARAR, ACTVT = '03' )` on both — the area of each row.

## 4. Launchpad space "Production Support" (documentation only)

| Page (in space `ZCD_OPS_SP_PROD_SUPPORT`, "Production Support") | Section / tiles |
|---|---|
| **Overview** (`ZCD_OPS_PG_OVERVIEW`) | App tile *Production support overview* (`ZCDOpsOverview-display` → OVP app `ZCD_OPS_OVW`); app tile *SAP job failures* (`ZCAJobFailure-display` → list report / object page on `ZUI_CA_OPS_JOBS_O4`, framework, 2026-11-11) with dynamic tile *Job failures today* (`JobFailure/$count?$filter=IsFailure eq true and IsToday eq true`); dynamic tiles *Stale monitors* (`MonitorFreshness/$count?$filter=IsStale eq true`), *Open critical exceptions* (`CriticalException/$count`), *Overdue critical* (`CriticalException/$count?$filter=IsOverdue eq true`), *Stale process checks* (`ProcessCheck/$count?$filter=IsStale eq true`, 2026-11-10) |
| **File monitoring** (`ZCD_OPS_PG_FMON`) | App tile *File monitoring dashboard* (`ZCDFileFlow-analyze`); tiles of `Dashboard_File_Monitoring.md` §6 |
| **EBS validation** (`ZCD_OPS_PG_EBS`) | App tiles *EBS validation dashboard* (`ZCDEbsValidation-analyze`, ALP on `EbsStatement`), *EBS findings* (`ZCDEbsValidation-analyzeFindings`), *EBS runs* (`ZCDEbsValidation-displayRuns`); tiles of `Dashboard_EBS_Validation.md` §5 |
| **Health checks** (`ZCD_OPS_PG_HCK`) | App tile *Health check dashboard* (`ZCDHealthCheck-analyze`); tiles of `Dashboard_Health_Check.md` §4 |
| **Transactions** (`ZCD_OPS_PG_TRX`) | App tile *Transactions dashboard* (`ZCDTransaction-analyze`); *Payment runs* (`ZCDTransaction-displayRuns`); after SE11 *Payment requests* (`ZCDPaymentRequest-analyze`); tiles of `Dashboard_Transactions.md` §5; *Payment trace* (`ZCDPaymentTrace-display`, proposed transaction) |
| **Exceptions** (`ZCD_OPS_PG_EXC`) | Existing owned-exceptions app (`ZCDOpsException-manage` → `ZUI_CA_OPS_EXC_O4`) |
| **Daily control review** (`ZCD_OPS_PG_REVIEW`, 2026-11-10) | App tile *Daily control review* (`ZCAControlReview-manage` → list report on `ZUI_CA_OPS_REV_O4`, framework); dynamic tiles *Awaiting review* (`ControlReview/$count?$filter=IsCurrentDay eq true and IsAwaitingReview eq true`), *Review overdue* (`... and IsReviewOverdue eq true`) |
| **Settings & ownership** (`ZCD_OPS_PG_SETTINGS`, 2026-11-10) | App tile *Settings & ownership* (`ZCAOpsConfig-maintain` → `ZUI_CA_OPS_CFG_O4`: controls, owner / backup / team, cut-off, guidance, covered checks; alert rules, purge targets); *Payment lifecycle stages* (`ZCDOpsConfig-maintain` → `ZUI_CD_OPS_CFG_O4`, entity `PayStage`); *Parameters* (`ZUI_CA_PARAM_O4`, e.g. `CONTROL_TIME_ZONE`, `CONTROL_TEAMS`, `EXC_REASON_CODES`) |

Dynamic tile URLs: `/sap/opu/odata4/sap/<binding>/srvd/sap/<service>/0001/<EntitySet>/$count?...` (path confirmed when each binding is published — VERIFY-ADT).

**Catalogs:** technical catalogs `ZCD_OPS_TC_OVW`, `ZCD_OPS_TC_FMON` (exists, step 1d.4), `ZCD_OPS_TC_EBS`, `ZCD_OPS_TC_HCK`, `ZCD_OPS_TC_TRX` (app descriptors + target mappings); business catalogs `ZCD_OPS_BC_<area>` referencing them; `ZCD_OPS_BC_COLL` (2026-11-10) for the collections operations role `Z_CD_OPS_COLL` (`config/auth_zcd_ops.md` §3): tiles *Owned exceptions* filtered to area `CD_COLL` and *Area dashboard* (`ZCAOpsDashboard-display`).

**Target mappings** (semantic object – action → app): `ZCDOpsOverview-display` → BSP `ZCD_OPS_OVW`; `ZCDFileFlow-analyze` → `ZCD_FMON_FLOW`; `ZCDEbsValidation-analyze` → `ZCD_EBS_DASH`; `ZCDHealthCheck-analyze` → `ZCD_HCK_DASH`; `ZCDTransaction-analyze` → `ZCD_TRX_DASH`; `ZCDPaymentRequest-analyze` → `ZCD_TRX_REQ` (after SE11); `ZCDOpsException-manage` → the owned-exceptions app; `ZCAOpsDashboard-display` → list report on `ZUI_CA_OPS_DASH_O4` (framework area dashboard, 2026-11-10); `ZCAJobFailure-display` → list report / object page on `ZUI_CA_OPS_JOBS_O4` (framework SAP job failures board, 2026-11-11; its object page navigates to `ZCAOpsException-manage` - the exceptions app - with the job's object key); `ZCDPaymentTrace-display` → transaction for report `ZCD_OPS_PAYMENT_TRACE` (**proposed**: create the transaction, map `FinId` → `P_FIN`, `SourceSystem` → `P_SRC`, `ClearingDoc` → `P_AUGBL`).

**Roles (PFCG, display only):**

| Business role | Space / pages | Catalogs | `S_SERVICE` | ZCD_OPS |
|---|---|---|---|---|
| `ZCD_OPS_PROD_SUPPORT` (L1 / L2, team leads) | Production Support, all pages | all `ZCD_OPS_BC_*` | `ZUI_CD_OPS_OVERVIEW_O4`, `ZUI_CD_FMON_FLOW_O4`, `ZUI_CD_EBS_DASH_O4`, `ZUI_CD_HCK_DASH_O4`, `ZUI_CD_TRX_DASH_O4`, `ZUI_CA_OPS_REV_O4`, `ZUI_CA_OPS_DASH_O4`, **`ZUI_CA_OPS_JOBS_O4`** (SAP job failures board, 2026-11-11) (+ `ZUI_CD_TRX_REQ_O4` after SE11) | ZCA_PARAR CD_FMON, CD_EBS, CD_HCK, CD_OPS, **CD_COLL**, **CD_JOBS** (SAP job failures, 2026-11-11 - the board, its overview cards and the area's exceptions) (collections request lifecycle, added 2026-11-10 - the process cards show its checks once they are active; a later business process adds its area here too, otherwise its cards stay empty for the user); ACTVT 03; BUKRS own company codes (or *) |
| `ZCD_OPS_REVIEWER` (shift reviewers, 2026-11-10) | Daily control review page | `ZCD_OPS_BC_REVIEW` | `ZUI_CA_OPS_REV_O4` | ZCA_PARAR of the control areas - CD_FMON, CD_EBS, CD_HCK, **CD_COLL** (control `BASE_REJECTS`, 2026-11-10); ACTVT **02** (sign-off, `ops-framework/docs/auth_zca_ops.md`) and 03 |
| `ZCD_OPS_FMON_DISPLAY`, `ZCD_OPS_EBS_DISPLAY`, `ZCD_OPS_HCK_DISPLAY`, `ZCD_OPS_TRX_DISPLAY` | one page each + Overview | the area catalog + `ZCD_OPS_BC_OVW` | the area binding + overview binding | that area, 03 |

The roles grant no 02 / 16 / 43 / 85; working an exception still needs the operator role (`config/auth_zcd_ops.md` §3).

## 5. Objects (`src/core`)

| Object | Type |
|---|---|
| `ZI_CD_OpsFreshU`, `ZR_CD_OpsFreshness`, `ZC_CD_OpsFreshness` (+ DDLX) | view (UNION), root, projection |
| `ZR_CD_OpsCritExc`, `ZC_CD_OpsCritExc` (+ DDLX) | root, projection |
| `ZC_CD_OPSOVERVIEW` | DCL |
| `ZUI_CD_OPS_OVERVIEW` | service definition (binding `ZUI_CD_OPS_OVERVIEW_O4` in ADT) |
| `ZR_CD_OpsCtlDay`, `ZC_CD_OpsCtlDay` (+ DDLX) | root over the framework's `ZR_CA_OpsCtlReview`, projection (control center, 2026-11-10) |
| `ZI_CD_PayLifeRun`, `ZI_CD_PayLifeCntU`, `ZI_CD_PayWorkSrc`, `ZR_CD_PayLifecycle`, `ZC_CD_PayLifecycle` (+ DDLX), `ZR_CD_PayOfDay`, `ZC_CD_PayOfDay` (+ DDLX) | payment lifecycle and its payments |
| `ZCD_OPS_PAYSTAGE` (+ draft `ZCD_D_PAYSTAGE`, entity `PayStage` of `ZUI_CD_OPS_CFG`) | table (C): stages of the lifecycle card |
| `src/hck`: `ZI_CD_OpsVarBank`, `ZI_CD_OpsVarFica`, `ZI_CD_OpsVarU`, `ZR_CD_OpsVariance`, `ZC_CD_OpsVariance` (+ DDLX) | reconciliation variances |
| `ZCL_CD_OPS_OVW_CDS_TEST` | class (test holder): `ltc_freshness` — `one_row_per_monitor_area`, `stale_by_area_threshold`; `ltc_critical` — `open_block_and_error_only`, `overdue_days_are_counted`, `bank_file_message_hidden`; 2026-11-10: `ltc_control_day` — `counters_of_the_review`; `ltc_life_run` — `newest_run_counts_once`; `ltc_lifecycle` — `stages_from_configuration`; `ltc_variance_leg` — `latest_beyond_tolerance`; `ltc_variance` — `disposition_from_exception` |
| `ProcessCheck` = framework `ZC_CA_OpsCheckStatus` (no suite object; counters and card annotations in the framework, tested by `ZCL_CA_OPS_DASH_CDS_TEST`) | exposed entity (2026-11-10) |
| `JobFailure` = framework `ZC_CA_OpsJobFailure` (no suite object; counters, card annotations and DCL `ZC_CA_OPSJOBFAILURE` in the framework, tested by `ZCL_CA_OPS_JOB_CDS_TEST`) | exposed entity (2026-11-11, SAP job failures) |

## 6. VERIFY-ADT

| Item | Fallback |
|---|---|
| UNION of three root views with literal elements | Three list cards (one per as-of entity of the area services) |
| One projection exposed in two service definitions (area + overview) | Copy the KPI / problem projections as `ZC_CD_Ovw*` (same R views) |
| OVP V4 KPI / analytical / list cards from `@UI.chart`, `@UI.dataPoint`, `@UI.selectionVariant`, `@UI.presentationVariant` | Card settings in the manifest (`annotationPath`, `selectionAnnotationPath`) |
| Second data source for the request card | Tile on the Transactions page instead |
| Navigation from a list-card row to another app by area | Card-level navigation only (owned-exceptions app) |
| Global filter fields `IsCurrentDay` / `BusinessDate` with `@Consumption.filter.defaultValue` on OVP V4 (control center) | Manifest `filterSettings` default; else the user selects the date |
| UNION ALL of aggregating selects (`ZI_CD_PayLifeCntU`), OR / comparisons in left outer join ON conditions (`ZI_CD_PayLifeRun`, `ZI_CD_OpsVar*`), concat of CHAR fields for the finding key | Three views; key built in ABAP is not an option (CDS only) - split per leg already done |
| Projection of the framework (`ZC_CA_OpsCheckStatus`) exposed in the overview service with its own metadata extension and DCL; `@Aggregation.default: #SUM` on a `transactional_query` projection for the KPI sums (cards *Business processes*, *Process checks - attention*) | Consumer projection `ZC_CD_OpsProcCheck` on `ZR_CA_OpsCheckStatus` with copied card annotations and DCL |
| KPI data point with `targetValueElement` (checks reviewed n / m) | Two data points (reviewed, controls) |
| SAP job failures (2026-11-11): framework projection `ZC_CA_OpsJobFailure` exposed in the overview service (DCL `ZC_CA_OPSJOBFAILURE`), KPI card on the `Today` selection variant with summed counters, list card variant `Today`; intent navigation `ZCAJobFailure-display` (VERIFY-ADT V66) | Consumer projection on `ZR_CA_OpsJobFailure` with copied card annotations; tile only |

## 7. QA1 cases

| ID | Case | Expected |
|---|---|---|
| OVP-01 | Open the overview with all monitors fresh | Freshness card: three green rows; each card shows today's numbers equal to its area dashboard |
| OVP-02 | Stop the FMON job > 15 min | Freshness: FMON red; tile *Stale monitors* = 1; Files card still shows the last numbers with their as-of |
| OVP-03 | Open B finding in EBS, overdue E in FMON | Critical exceptions card lists both, overdue first; HCK warnings not listed |
| OVP-04 | Tap each card | Opens the area dashboard (intent per §4) |
| OVP-05 | User with HCK only | Health cards filled; other cards and rows empty (DCL) |
| OVP-06 | EBS bank-file statement error with the account in the message | Listed without message |
| OVP-07 | Before part B of the transactions dashboard | No "Requests" card; all other cards work |
| OVP-08 | ST05 while the page loads | SELECT only; one request batch per card |
| OVP-09 | Control center at 09:15 Chicago, two controls not signed off (cut-offs 08:30 / 09:00) | *Checks reviewed* 10 / 12, 2 awaiting, both overdue; the review app lists the same two |
| OVP-10 | Sign off a control with *Action required* without next action | Refused (076); with observation and next action saved, counter +1 |
| OVP-11 | New error finding of a signed-off control | Awaiting review again; *Controls flagged* unchanged count rule (worst live finding) |
| OVP-12 | Business date = yesterday | All control center cards show yesterday; freshness and critical exceptions unchanged |
| OVP-13 | RECON3 break on a group-day, then *Classify* TIMING in the exceptions app | *Open variances* −1, *Classified as timing* +1 |
| OVP-14 | Peak day (2 M payments) - payment lifecycle card and *View payments* | Counts equal SE16H on DPAYH (LAUFD, XVORL blank, newest run per DOC1R); response < 5 s; PlanViz recorded (§11 of `Performance_Review.md`) |
| OVP-15 | User with CD_OPS / BUKRS US01 only | Lifecycle and payments of US01 only |
| OVP-16 | One business process active (test area), one check with an open error in company code 1000, one check whose schedule group has not run within its threshold | *Business processes*: registered checks = active checks (not doubled by the 1000 slice), flagged 1, stale 1; *Process checks - attention* lists both, error first; a fresh check without exceptions is not listed; a user of 2000 sees the stale check but not the 1000 slice; tap opens the area dashboard |

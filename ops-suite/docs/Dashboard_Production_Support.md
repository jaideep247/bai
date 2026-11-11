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
| **Response times** (operations response features, 2026-11-11) | KPI | `ExceptionMetric` (framework projection `ZC_CA_OpsExcMetric`; data points `Raised`, `Mtta` = mean minutes to assign, `Mttr` = mean minutes to resolve, `Open`, `Reopened`; global filter: month of the raise) | *n exceptions raised, MTTA m min, MTTR r min, o open, x raised again after resolve* for the user's areas and company codes | Analytical list page *Exception response times* (`ZCAOpsMetrics-analyze` → `ZUI_CA_OPS_MET_O4`) |
| **Shift handover** (2026-11-11) | List (table) | `ShiftHandover` (framework projection `ZC_CA_OpsHandover`; selection variant `Attention`; data points `New`, `Resolved`, `Open`, `Escalated`, `AwaitingSignOff`, `DowntimeNext`) | Per team, area and company code since the start of the previous shift: new, resolved, still open, escalated, controls awaiting sign-off, planned downtime active / next shift | List report *Shift handover* (`ZCAOpsHandover-display` → `ZUI_CA_OPS_HOVR_O4`) |
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
| **Shift and response** (`ZCD_OPS_PG_SHIFT`, 2026-11-11) | App tiles *Shift handover* (`ZCAOpsHandover-display` → `ZUI_CA_OPS_HOVR_O4`), *Exception response times* (`ZCAOpsMetrics-analyze` → `ZUI_CA_OPS_MET_O4`), *Planned downtime* (`ZCAOpsDowntime-manage` → `ZUI_CA_OPS_DTW_O4`; plan, approve, *End now*); dynamic tiles *Active planned downtime* (`Downtime/$count?$filter=WindowStatus eq 'A'`), *Downtime awaiting approval* (`... eq 'P'`), *Handover - needs attention* (`ShiftHandover/$count?$filter=IsAttention eq true`) |
| **Settings & ownership** (`ZCD_OPS_PG_SETTINGS`, 2026-11-10) | App tile *Settings & ownership* (`ZCAOpsConfig-maintain` → `ZUI_CA_OPS_CFG_O4`: controls, owner / backup / team, cut-off, guidance, covered checks; alert rules, purge targets); *Payment lifecycle stages* (`ZCDOpsConfig-maintain` → `ZUI_CD_OPS_CFG_O4`, entity `PayStage`); *Parameters* (`ZUI_CA_PARAM_O4`, e.g. `CONTROL_TIME_ZONE`, `CONTROL_TEAMS`, `EXC_REASON_CODES`) |

Dynamic tile URLs: `/sap/opu/odata4/sap/<binding>/srvd/sap/<service>/0001/<EntitySet>/$count?...` (path confirmed when each binding is published — VERIFY-ADT).

**Catalogs:** technical catalogs `ZCD_OPS_TC_OVW`, `ZCD_OPS_TC_FMON` (exists, step 1d.4), `ZCD_OPS_TC_EBS`, `ZCD_OPS_TC_HCK`, `ZCD_OPS_TC_TRX` (app descriptors + target mappings); business catalogs `ZCD_OPS_BC_<area>` referencing them; `ZCD_OPS_BC_COLL` (2026-11-10) for the collections operations role `Z_CD_OPS_COLL` (`config/auth_zcd_ops.md` §3): tiles *Owned exceptions* filtered to area `CD_COLL` and *Area dashboard* (`ZCAOpsDashboard-display`).

**Target mappings** (semantic object – action → app): `ZCDOpsOverview-display` → BSP `ZCD_OPS_OVW`; `ZCDFileFlow-analyze` → `ZCD_FMON_FLOW`; `ZCDEbsValidation-analyze` → `ZCD_EBS_DASH`; `ZCDHealthCheck-analyze` → `ZCD_HCK_DASH`; `ZCDTransaction-analyze` → `ZCD_TRX_DASH`; `ZCDPaymentRequest-analyze` → `ZCD_TRX_REQ` (after SE11); `ZCDOpsException-manage` → the owned-exceptions app; `ZCAOpsDashboard-display` → list report on `ZUI_CA_OPS_DASH_O4` (framework area dashboard, 2026-11-10); `ZCAJobFailure-display` → list report / object page on `ZUI_CA_OPS_JOBS_O4` (framework SAP job failures board, 2026-11-11; its object page navigates to `ZCAOpsException-manage` - the exceptions app - with the job's object key); `ZCDPaymentTrace-display` → transaction for report `ZCD_OPS_PAYMENT_TRACE` (**proposed**: create the transaction, map `FinId` → `P_FIN`, `SourceSystem` → `P_SRC`, `ClearingDoc` → `P_AUGBL`).

**Roles (PFCG, display only):**

| Business role | Space / pages | Catalogs | `S_SERVICE` | ZCD_OPS |
|---|---|---|---|---|
| `ZCD_OPS_PROD_SUPPORT` (L1 / L2, team leads) | Production Support, all pages | all `ZCD_OPS_BC_*` | `ZUI_CD_OPS_OVERVIEW_O4`, `ZUI_CD_FMON_FLOW_O4`, `ZUI_CD_EBS_DASH_O4`, `ZUI_CD_HCK_DASH_O4`, `ZUI_CD_TRX_DASH_O4`, `ZUI_CA_OPS_REV_O4`, `ZUI_CA_OPS_DASH_O4`, **`ZUI_CA_OPS_JOBS_O4`** (SAP job failures board, 2026-11-11), `ZUI_CA_OPS_DTW_O4`, `ZUI_CA_OPS_MET_O4`, `ZUI_CA_OPS_HOVR_O4` (operations response features, 2026-11-11) (+ `ZUI_CD_TRX_REQ_O4` after SE11) | ZCA_PARAR CD_FMON, CD_EBS, CD_HCK, CD_OPS, **CD_COLL**, **CD_JOBS** (SAP job failures, 2026-11-11 - the board, its overview cards and the area's exceptions) (collections request lifecycle, added 2026-11-10 - the process cards show its checks once they are active; a later business process adds its area here too, otherwise its cards stay empty for the user); ACTVT 03; BUKRS own company codes (or *) |
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
| `ExceptionMetric` = framework `ZC_CA_OpsExcMetric`, `ShiftHandover` = framework `ZC_CA_OpsHandover` (no suite object; measures, data points and DCLs in the framework, tested by `ZCL_CA_OPS_MET_CDS_TEST` / `ZCL_CA_OPS_HOVR_CDS_TEST`) | exposed entities (operations response features, 2026-11-11; block of their own in `ZUI_CD_OPS_OVERVIEW`) |

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
| KPI card with `@Aggregation.default: #AVG` measures (`Mtta`, `Mttr` of `ExceptionMetric`) on a `transactional_query` projection (2026-11-11) | Card on the analytical list page's chart instead; or two KPI cards of sums |
| List card on `ShiftHandover` (aggregated framework view, keys team / area / company code) | Tile *Handover - needs attention* and the list report only |

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

## 8. Service health, process flow and the persona pages (2026-11-11)

Status: CDS, configuration seeds and annotations written, checked offline (abaplint 0 issues); **not activated**; ABAP Unit not executed (VERIFY V91-V93, V97 of `ops-framework/docs/VERIFY.md`).

### 8a. Service health (entities `ServiceHealth`, `ServiceContributor` of `ZUI_CD_OPS_OVERVIEW`)

| Element | Rule |
|---|---|
| Business services | `ZCD_OPS_SVC` (core configuration app, entity *Business services*; seed `config/service_register.csv`): Collections, Disbursements, Bank statements, Interfaces, Batch / jobs, Reconciliation - label, order, points per open B / E / W finding (25 / 15 / 5), points per stale monitor (20), bands good >= 90, watch >= 70 |
| What a service covers | `ZCD_OPS_SVCMAP` (entity *What a business service covers*; seed `config/service_map.csv`): area + `AREA` (every finding of the area) / `CONTROL` (the covered checks of a control of the daily review) / `RULE_ID` / `CHECK_CODE` / `GROUP2` + exact value + weight. Batch / jobs maps area `CD_JOBS` (build J): it finds nothing until J is merged |
| Score | 100 - points, at least 0, per service, business date and company-code slice; points = severity points x weight of each **live** finding (open, assigned, superseded) of the runs of the date - a problem raised by several runs or caught by two rows counts once (object key, highest points) - plus stale points of the service's areas on the current business date (`ZR_CD_OpsFreshness`) |
| Worst contributors | `ServiceContributor`: per service, date, company code, area and check code - problems and points, largest first |
| Cards | List card *Service health* (presentation variant `Worst`, data point `Score` with criticality, selection variant `Today`); list card *Service health - worst contributors* (`Worst`); header navigation to the exceptions app filtered by area |

**Patterns - decision.** The brief asked for check-code patterns (PCRE). CDS cannot apply a pattern held in a column (`replace_regexpr` takes a literal) and the house rule says SQL never receives a pattern (`DEVELOPMENT_STANDARDS.md` §2). The service map therefore uses **exact values**, exactly like the framework's covered-check rows of a control (`ZCA_OPS_CTLCHK`); several codes = several rows, and a `CONTROL` row follows a control's checks without repeating them. Alternative (decision **D-B1**): a CDS table function (AMDP) with HANA `LIKE_REGEXPR` on the configured pattern - more power, but a database-specific object and a new VERIFY item.

**Severity weights - decision.** The weights and bands are columns of the service register, not ZCA_PARAM parameters: CDS reads them directly (one source, validated by the configuration app, transported like every row), a service may weigh differently, and a parameter read only by CDS would have no ABAP reader (portable check `params_used`). Same for the expected days of a process-flow stage (`ZCD_OPS_PAYSTAGE-STUCK_DAYS`). No `SVC_` / `FLOW_` / `VOL_` / `PERS_` parameter was needed.

### 8b. Company-code isolation of the score - decision

A score is **not additive** (100 - 30 and 100 - 15 are not 100 - 45), so it is never summed over company codes. Each row is complete for its slice: the **area-level row** (company code blank) = area-level problems + stale monitors; a **company-code row** = area-level problems + that company code's problems + stale monitors. The DCL `ZC_CD_OPSOVERVIEW` applies the framework rule (area authorised and (company code blank or (area, company code) authorised)), so a user of company code 1000 sees the area-level row and the 1000 row - never points of another company code; a central user sees the area-level row and one row per company code with problems (worst first). Rejected: area-level only (a user of 1000 would see a score lowered by 2000's problems).

### 8c. Process flow (entity `PaymentFlow`)

Per business date, company code and configured stage (`ZCD_OPS_PAYSTAGE` order): payments in the stage, **stuck** (older than `STUCK_DAYS` of the stage: calendar days since the run date / due date - the age of a status is not stored, so the age of the payment is used), reached (in the stage or a later one of the same source), **drop** from the previous stage, criticality (0 final stage, 3 none stuck, 2 stuck, 1 stuck for more than twice the expected time). Delivered expected days (`config/pay_stages.csv`): ISSUED 1, CONFIRMED 4, request stages 0-1 - **confirm with the payments team**. Card now: list card *Process flow* (row criticality) and bar card `FlowBars`. A flow diagram needs the custom card `ui/cards/processflow` (spec `docs/Process_Flow_Card.md`, VERIFY V97).

### 8d. Payment model and the three persona pages (service `ZUI_CD_PAYM`)

Generated from the mapping spec `config/payment_model/mapping.json` with the framework's product templates (`ops-framework/docs/ADDING_A_CUSTOMER_PAYMENT_MODEL.md`): entities `PaymentCategory` (cube), `PaymentTrend`, `Payment` (drill-down list + object page), `PaymentRequestLink`, `ExceptionTrend`; `PaymentRequest`, attempts and the feeder timeline are **pending** (request-log field names VERIFY V82, V90; generated for review into `config/payment_model/pending`) and appear when the spec section is set active. **Decision:** the control center page `ZCD_OPS_OVW` stays the shared page of the support lead and keeps working unchanged; the three persona pages are separate OVP app descriptors on the one service `ZUI_CD_PAYM` (+ the service health / flow entities of `ZUI_CD_OPS_OVERVIEW` as second data source of the managers' and IT pages - or a tile, if the second model is not supported, as §2).

**Business users** (payment operations, source / business owners) - app `ZCD_PAYM_BIZ`, plain texts (dimension texts of `ZCA_OPS_PMDIM`), amounts per currency:

| Card | Entity / annotation | Question it answers | Drill-down |
|---|---|---|---|
| Payments by source and status | `PaymentCategory` chart `BizBySourceStatus`, variant `Today` | How many payments of each feeder system are issued / confirmed / cleared / returned today? | `Payment` list -> object page -> payment trace |
| Payments by payment type and status | `BizByClassStatus` | Which payment types (ACH, wire, cheque, card ...) are still open? | as above |
| Payments by source and payment type | `BizBySourceClass` | How does each source pay? | as above |
| Amount by source (per currency) | `BizAmountBySource`, variant `LocalCurrency` (+ `OtherCurrencies`) | How much money per source - in the company code currency, other currencies separately | as above |
| Requests not paid on the due date | `TransactionKpi` / `TransactionProblem` (existing, request rows `REQ_NOT_PAID`); per source x request status after V82 / V84 | Which requests missed their date? | payment trace |
| Returns / retrievals / stops by source | `BizBySourceStatus` filtered to RETURNED / RETRIEVED / STOPPED | Which sources have returned or stopped payments? | as above |
| Payments by house bank / company code | `BizByBank`, `BizByCompany` | Volumes per bank and per company code | as above |
| Daily payments by source / transaction | `PaymentTrend` `BizDailyBySource`, `BizDailyByTransaction` (transaction blank until V83), variant `Last30` | Is today normal for this source? | the day's `Payment` list |
| Stripe premium refunds | not built - depends on P2 / R3 (`config/control_seed.md` §2a) | - | - |

**Managers** - app `ZCD_PAYM_MGR`:

| Card | Entity / annotation | Question |
|---|---|---|
| Volume vs same weekday last week | `PaymentTrend` `MgrVolumeVsLastWeek`, variant `Last30`; variant `PeakDays` | Is the volume normal? Was a peak handled? |
| On time and late by payment type / house bank / company code | `PaymentCategory` `MgrOnTimeByClass`, `MgrOnTimeByBank`, `MgrOnTimeByCompany` (late = worklist finding `PAYMENT_NOT_CLEARED`: the in-flight rules of `config/hck_seed.md` §8 per method class - reused, not restated) | Share paid on time |
| Late payments per day | `PaymentTrend` `MgrLatePerDay` | Is lateness growing? |
| Amount per day per currency | `MgrAmountPerDay` | Money moved |
| Service health | `ServiceHealth` | Which business service needs attention? |
| Daily controls signed off / flagged | `ControlDay` cards (existing) | Is the shift closed? |
| Exceptions raised vs resolved | `ExceptionTrend` `MgrRaisedResolved` | Is the backlog shrinking? |
| Open exceptions by age | `CriticalException` (existing, `DaysOverdue`) | What is overdue? |
| Response times (time to assign / resolve) | **placeholder** - entities of build A, wired by the lead at merge by the names in A's documentation | How fast does the team react? |
| Reconciliation variances | `ReconVariance` (existing) | Where does money not tie out? |

**IT support** - app `ZCD_PAYM_IT` (counts; amounts only on the object page - the `SHOW_AMOUNTS` idea of the alert e-mails):

| Card | Entity / annotation | Question |
|---|---|---|
| Monitor freshness | `MonitorFreshness` (existing) | Are the monitors alive? |
| File / interface status | `FileFlowKpi`, `FileFailure` (existing) | Which file failed? |
| SAP job failures incl. "parent finished, child failed" | **placeholder** - build J, area `CD_JOBS` | Which job broke? |
| Open exceptions with check codes and runbook links | `CriticalException` (existing) + runbook link of build A (**placeholder**) | What do I fix first? |
| Process checks | `ProcessCheck` (existing) | Which process check is red or stale? |
| Open payments by method class and outcome | `PaymentCategory` `ItOpenByClass` | What is in flight / undetermined / inconsistent? |
| Evidence gaps by method class | `ItGapsByClass` (cheque register / ECT status for cheques, Stripe payout for cards, bank ACK for ACH / wire - the worklist finding) | Which evidence is missing? |
| Payments per house bank and status | `ItByBankStatus` (heat map) | Is one bank stuck? |
| Daily failures per area | `ExceptionTrend` `ItRaisedByArea` | Which area fails more? |
| Payment trace entry | tile *Payment trace* and the object page link | Follow one payment |

### 8e. Company code view and house bank view

Both are card sections with the company code / house bank as first dimension on each persona page, not only filters: payments by company code (`BizByCompany`), on time by company code (`MgrOnTimeByCompany`), service health per company code (slice, §8b), controls flagged per company-code slice (`ControlDay`), open exceptions per company code (`CriticalException`), variances (`ReconVariance` - RECON3 groups carry the company code). **The company-code DCL is what limits each user to his company codes**: a user of 1000 sees only 1000 plus the area-level rows (blank company code) on every card; counts and amounts are summed after the DCL. House bank: payments per house bank and status (`BizByBank`, `ItByBankStatus`), on time per house bank (`MgrOnTimeByBank`); files and bank ACKs per house bank, the PRISM queue per bank (2-minute throttle per bank queue) and BAI statements received / posted by the 10:00 CST deadline per payment-engine account (FEBEP-XBLNR rule) come from the existing FMON and EBS dashboards as cards of the IT page. The house bank account ID (DPAYH-HKTID) is blank until V87; bank account numbers are never read (masking rule of the payment trace).

### 8f. Amounts and currencies

Every amount is grouped with its currency (`@Semantics.amount.currencyCode`, currency in every amount chart); two currencies are never added; no conversion (no exchange-rate type is confirmed - a reporting-currency view is **decision D-B2**: rate type, rate date and the reporting currency are open questions). KPI cards show the **company code currency** (variant `LocalCurrency`) with *Other currencies* as second variant - no parameter needed. Amounts are **absolute** (DPAYH-RWBTR, as the lifecycle and the trace show it); collections and disbursements are separated by the flow dimension, never netted. Request amounts stay empty until the request-log fields are confirmed (V82). Business and manager pages show amounts; the IT page shows counts.

### 8g. Business-date trend

`PaymentTrend`: per business date and category - count, late, amount per currency, the same weekday of the previous week (same category and currency), days ago, peak day (company code volume >= 1 000 000 payments, spec `peak_day_min`). Aggregated in the database; the window is the payment model's (45 days of DPAYH by LAUFD - a key range, `Performance_Review.md` §12), the cards select the last 30 days. The missing-volume baselines (`B_VOL_*`, same weekday) are the metric history of the health check dashboard - shown next to the trend, not recomputed. Requests by received date: after V82 / V85 (fallback: requests by due date from the worklist, as today).

### 8h. QA1 cases

| ID | Case | Expected |
|---|---|---|
| OVP-17 | Two open E findings of `PAYMENT_FILES` checks, one in 1000, one area-level; FMON monitor stale | Disbursements: area-level row 100 - 15 - 20 = 65, 1000 row 50; a user of 2000 sees 65 only; contributors list both, largest first |
| OVP-18 | The same late file raised by three runs of the day | Counted once (highest points) |
| OVP-19 | Payments of 3 days ago still ISSUED | Process flow: ISSUED stuck, critical (more than twice 1 day); drop ISSUED -> CONFIRMED = the ISSUED count |
| OVP-20 | Service map row `BATCHJOBS` / `CD_JOBS` before build J | Batch / jobs shows 100, no error |
| PM-01 | Business page, payments of today by source and status | Counts equal SE16H on DPAYH (LAUFD, XVORL blank, newest run per DOC1R); source blank for payments without worklist row |
| PM-02 | USD and CAD payments of one source | Two amounts, never one total; KPI in the company code currency, *Other currencies* the rest |
| PM-03 | User of company code 1000 | Every card and the payment list show 1000 only |
| PM-04 | Payment object page of a payment settling two FIN numbers | Requests table lists both; the payment trace link opens the trace |
| PM-05 | Trend on a peak day | Peak flag, volume vs the same weekday of the previous week |

## 9. Not built in this change - ledger to the universal journal, reversals and clearing resets (designed 2026-11-11)

**Ledger / reconciliation to ACDOCA.** (a) Per payment: payment -> FI-CA documents (DFKKOP / DFKKKO, mapping) -> reconciliation key -> summary G/L document (DFKKKO-FIKEY = DFKKSUMC-FIKEY = BKPF-AWKEY, AWTYP `TRACE_GL_AWTYP`, same company code, not reversed - the payment trace's rule) -> its journal lines (ACDOCA only by RCLNT / RLDNR / RBUKRS / GJAHR / BELNR; ledger from a parameter, default `0L` - VERIFY). The G/L receives **consolidated** amounts per clearing account and FIKEY: the page shows the summary document and the payment's **share** (its amount within the FIKEY total), never a 1:1 G/L line. Bank side: FEBEP -> clearing line in BSEG (XREF2 = AUGBL) -> journal line by company code / year / document / line (VERIFY that ACDOCA-BUZEI maps 1:1 to the BSEG line in 2023; ACDOCA is never searched by reference). (b) Group level per business date, company code, G/L account (RECON3 clearing / transit accounts), currency: subledger vs journal vs bank totals with the existing variance buckets - the three-way reconciliation already stores the legs and differences (`A_RECON_3WAY`, `ZCD_HCK_METRIC`, `ReconVariance`): **reuse, not recompute**; a journal leg (ACDOCA aggregated by RBUKRS, RACCT, BUDAT for the configured accounts) only where it adds evidence over BSEG / BKPF. Line-item accounting attributes (ledger, period, document type, dates, account + text, posting key, debit / credit, amounts in transaction / company code / group currency each with its currency, assignment, text, clearing, profit center, segment, business area, cost center, reference key, reversal; FI-CA: FIKEY, main / sub transaction, contract account, partner masked, document / item, DFKKSUMC lines; bank: statement, line, transaction code, posted flags) with roll-up account x date x currency -> FIKEY -> FI-CA documents -> line items -> payment / request / feeder. Product part: contract section `ledger` (standard S/4HANA tables allowed in the product; DFKK* only in the mapping); every standard field (DRCRK, KSL / RKCUR, SEGMENT, XREVERSAL ...) on the VERIFY-SE11 list first. **Remaining: contract section, templates, FS-CD mapping, CDS tests (share of summary, per-currency totals, account / date aggregation, reversal exclusion).**

**Document-change events.** Event model in the product (REVERSAL / CLEARING_RESET / RECLEARING / GL_REVERSAL / VOID_REISSUE; original, new and reversal document, user, time, reason); FS-CD mapping: DFKKKO-STBEL, worklist source REVERSALS / outcome REVERSED (reuse), clearing reset history `TRACE_SRC_HISTORY` (DFKKRAPT / XRAGL, `Payment_Trace.md` §4.2 - VERIFY-SE11, inactive until confirmed), stop and reissue (new payment document and cheque number), returns (DFKKRP) apart. "Changes" timeline on the payment / request page with the old -> new clearing document (the bank line keeps the OLD AUGBL - the known cause of clearing-account breaks). Risk findings (suite, E, set-based evidence reads): reset / reversal after the payment left SAP (file sent, bank ACK, bank line, cheque cashed) = possible double payment; reset without re-clearing after N days; reversal without its G/L reversal; bank line referencing a reset / reversed clearing document (variance bucket "reset / reversal"). User names only where the exceptions app already shows them. **Remaining: all of it.**
| OVP-17 | Card *Response times* (2026-11-11), month = last month, user of company code 1000 | Raised / open / re-opened equal the exceptions app filtered to the user's areas, area-level and 1000 rows; MTTA / MTTR equal the averages of `ZUI_CA_OPS_MET` for the same filter (suite V81) |
| OVP-18 | Card *Shift handover* at 15:00 CST (ONSITE shifts 06:00 / 14:00 / 22:00), one escalation sent at 11:00, one window starting at 23:00 | Since 06:00: the escalation counted, the window under *next shift*; tile *Handover - needs attention* counts the rows with open or escalated exceptions or controls awaiting sign-off |

# Production support overview page and launchpad space

> **First principle:** support starts every shift from one page that says, per area, "is the monitor alive, and is anything red" — and each card opens the dashboard that proves it.
> **Analogy:** a hospital ward's nurses' station board — one row per patient (area) with vital signs and a red light, the board shows when each reading was taken, and a tap on a row opens the full chart.

Status 2026-11-06: CDS and service written and statically checked offline (abaplint 0 issues); **not activated, ABAP Unit not executed**. The overview page app (manifest) and every launchpad object (space, pages, catalogs, tiles, target mappings, roles) are **documentation only** — the repository carries no FLP or UI5 objects; they are created in the target system (step 1f of `Implementation_Order.md`).

## 1. The page

Fiori elements **overview page (OVP)**, OData V4, one data source: service `ZUI_CD_OPS_OVERVIEW` (binding `ZUI_CD_OPS_OVERVIEW_O4`). Read-only.

| Card | Card type | Entity (overview service) | Shows | Navigates to |
|---|---|---|---|---|
| **Monitor freshness** | List (table) | `MonitorFreshness` | FMON, EBS, HCK: end of the last completed run, age, threshold (15 min / 26 h / 26 h), **stale** (red) | The area's dashboard (row) / `ZCDFileFlow-analyze` (card header) |
| **Open critical exceptions** | List | `CriticalException` (selection variant `Overdue` as tab) | Open / assigned B and E findings of every area, overdue first: area, check code, object, owner, due date, days overdue | Owned-exceptions app (`ZCDOpsException-manage`, `ZUI_CD_OPS_EXC_O4`) |
| **Files** | KPI + analytical | `FileFlowKpi` (variant `Today`, chart `FilesByBucket`, data points `Rejected`, `Unprocessed`, `Breached`, `MonitorAge`) | Files per flow bucket today, rejected / unprocessed / breached | `ZCDFileFlow-analyze` (file monitoring ALP) |
| Files – latest failures | List | `FileFailure` | Rejected, partial, SLA-breached files | `ZCDFileFlow-analyze` |
| **EBS** | KPI + analytical | `EbsKpi` (variant `Latest`, chart `LinesByOutcome`, data points `Failed`, `Blocked`, `Unevaluated`, `PostingIncomplete`, `ValidationAge`) | Lines by outcome of the last run, not evaluated, POSTING_INCOMPLETE | `ZCDEbsValidation-analyze` |
| EBS – latest problems | List | `EbsProblem` | Open B / E findings, POSTING_INCOMPLETE | `ZCDEbsValidation-analyze` |
| **Health checks** | KPI | `HealthKpi` (data points `OverallRag`, `RedChecks`, `AmberChecks`, `Overdue`, `ReportAge`) | Overall RAG of the last morning report, red / amber checks, overdue exceptions, health-score text | `ZCDHealthCheck-analyze` |
| Health checks – reds | List | `HealthRedCheck` | Red and amber checks of the last run | `ZCDHealthCheck-analyze` |
| **Transactions** | Analytical + KPI | `TransactionKpi` (chart `Funnel`, variant `Today`, data points `Transactions`, `Paid`, `Settled`, `Returned`, `Open`) | Funnel posted → paid → settled, returned, open — live | `ZCDTransaction-analyze` |
| Transactions – errored / stuck | List | `TransactionProblem` | Returned, reversed, overdue open disbursements | `ZCDTransaction-analyze` (row: `ZCDPaymentTrace-display`, proposed) |
| Requests (after SE11) | Analytical | `PaymentRequest` of `cds/ZUI_CD_TRX_REQ` (second data source, §2) | Requested → processed → posted → paid → acknowledged → settled; errored | Request funnel app |

Global filter: none mandatory (the area entities have different dimensions); each card applies its own selection variant. The page is as fresh as its sources: three cards read monitor runs (the freshness card says how old), the transactions cards are live.

## 2. Design decision — one overview service (VERIFY-ADT for the alternative)

**Chosen: one service `ZUI_CD_OPS_OVERVIEW`** that re-exposes the KPI and latest-problem projections of the four area dashboards (the same CDS objects as in the area services, the same DCL roles) and adds two cross-area entities (`ZC_CD_OpsCritExc`, `ZC_CD_OpsFreshness`).

Why: (1) the OVP needs one model per card; with one service every card uses the default model, one `$metadata`, one binding to publish and one `S_SERVICE` per role; (2) no CDS is duplicated — exposing a projection in two service definitions is supported; (3) authorisation stays per area (each projection keeps its role), so a user sees only the cards' rows of the areas he may display; (4) the cross-area cards (critical exceptions, freshness) need a home anyway.

Alternative: an OVP over the four area services as separate data sources (`dataSources` in the manifest, `model` per card). OVP supports several models, but mixed-model V4 cards, global filter and navigation across models are release-dependent — **VERIFY-ADT** on the target UI5 version. It is used only for the cds/ request funnel (`ZUI_CD_TRX_REQ`), which must stay out of the abapGit service: added as a second data source with one card when part B of the transactions dashboard is activated. If the second model is not supported, the "Requests" card is replaced by a tile on the Transactions page (§4).

## 3. Cross-area entities

| Entity | CDS | Rule |
|---|---|---|
| `MonitorFreshness` | `ZR_CD_OpsFreshness` over `ZI_CD_OpsFreshU` (UNION of `ZR_CD_FmonAsOf`, `ZR_CD_EbsAsOf`, `ZR_CD_HckAsOf`) | One row per batch monitor; each area's completion rule and threshold (FMON: full run, variant ALL, 15 min; EBS: any variant, S/W/E/N, 26 h; HCK: S/W/E, 26 h); no completed run = stale. Transactions are live — no row |
| `CriticalException` | `ZR_CD_OpsCritExc` over `ZCD_OPS_FINDING` | Disposition O / A, severity B / E, all areas; GROUP1 never exposed; EBS bank-file statement messages hidden; `DaysOverdue` = today − due date |

DCL `ZC_CD_OPSOVERVIEW`: `pfcg_auth( ZCD_OPS, ZCD_PE_AREA, ACTVT = '03' )` on both — the area of each row.

## 4. Launchpad space "Production Support" (documentation only)

| Page (in space `ZCD_OPS_SP_PROD_SUPPORT`, "Production Support") | Section / tiles |
|---|---|
| **Overview** (`ZCD_OPS_PG_OVERVIEW`) | App tile *Production support overview* (`ZCDOpsOverview-display` → OVP app `ZCD_OPS_OVW`); dynamic tiles *Stale monitors* (`MonitorFreshness/$count?$filter=IsStale eq true`), *Open critical exceptions* (`CriticalException/$count`), *Overdue critical* (`CriticalException/$count?$filter=IsOverdue eq true`) |
| **File monitoring** (`ZCD_OPS_PG_FMON`) | App tile *File monitoring dashboard* (`ZCDFileFlow-analyze`); tiles of `Dashboard_File_Monitoring.md` §6 |
| **EBS validation** (`ZCD_OPS_PG_EBS`) | App tiles *EBS validation dashboard* (`ZCDEbsValidation-analyze`, ALP on `EbsStatement`), *EBS findings* (`ZCDEbsValidation-analyzeFindings`), *EBS runs* (`ZCDEbsValidation-displayRuns`); tiles of `Dashboard_EBS_Validation.md` §5 |
| **Health checks** (`ZCD_OPS_PG_HCK`) | App tile *Health check dashboard* (`ZCDHealthCheck-analyze`); tiles of `Dashboard_Health_Check.md` §4 |
| **Transactions** (`ZCD_OPS_PG_TRX`) | App tile *Transactions dashboard* (`ZCDTransaction-analyze`); *Payment runs* (`ZCDTransaction-displayRuns`); after SE11 *Payment requests* (`ZCDPaymentRequest-analyze`); tiles of `Dashboard_Transactions.md` §5; *Payment trace* (`ZCDPaymentTrace-display`, proposed transaction) |
| **Exceptions** (`ZCD_OPS_PG_EXC`) | Existing owned-exceptions app (`ZCDOpsException-manage` → `ZUI_CD_OPS_EXC_O4`) |

Dynamic tile URLs: `/sap/opu/odata4/sap/<binding>/srvd/sap/<service>/0001/<EntitySet>/$count?...` (path confirmed when each binding is published — VERIFY-ADT).

**Catalogs:** technical catalogs `ZCD_OPS_TC_OVW`, `ZCD_OPS_TC_FMON` (exists, step 1d.4), `ZCD_OPS_TC_EBS`, `ZCD_OPS_TC_HCK`, `ZCD_OPS_TC_TRX` (app descriptors + target mappings); business catalogs `ZCD_OPS_BC_<area>` referencing them.

**Target mappings** (semantic object – action → app): `ZCDOpsOverview-display` → BSP `ZCD_OPS_OVW`; `ZCDFileFlow-analyze` → `ZCD_FMON_FLOW`; `ZCDEbsValidation-analyze` → `ZCD_EBS_DASH`; `ZCDHealthCheck-analyze` → `ZCD_HCK_DASH`; `ZCDTransaction-analyze` → `ZCD_TRX_DASH`; `ZCDPaymentRequest-analyze` → `ZCD_TRX_REQ` (after SE11); `ZCDOpsException-manage` → the owned-exceptions app; `ZCDPaymentTrace-display` → transaction for report `ZCD_OPS_PAYMENT_TRACE` (**proposed**: create the transaction, map `FinId` → `P_FIN`, `SourceSystem` → `P_SRC`, `ClearingDoc` → `P_AUGBL`).

**Roles (PFCG, display only):**

| Business role | Space / pages | Catalogs | `S_SERVICE` | ZCD_OPS |
|---|---|---|---|---|
| `ZCD_OPS_PROD_SUPPORT` (L1 / L2, team leads) | Production Support, all pages | all `ZCD_OPS_BC_*` | `ZUI_CD_OPS_OVERVIEW_O4`, `ZUI_CD_FMON_FLOW_O4`, `ZUI_CD_EBS_DASH_O4`, `ZUI_CD_HCK_DASH_O4`, `ZUI_CD_TRX_DASH_O4` (+ `ZUI_CD_TRX_REQ_O4` after SE11) | ZCD_PE_AREA FMON, EBS, HCK, CORE; ACTVT 03; BUKRS own company codes (or *) |
| `ZCD_OPS_FMON_DISPLAY`, `ZCD_OPS_EBS_DISPLAY`, `ZCD_OPS_HCK_DISPLAY`, `ZCD_OPS_TRX_DISPLAY` | one page each + Overview | the area catalog + `ZCD_OPS_BC_OVW` | the area binding + overview binding | that area, 03 |

The roles grant no 02 / 16 / 43 / 85; working an exception still needs the operator role (`config/auth_zcd_ops.md` §3).

## 5. Objects (`src/core`)

| Object | Type |
|---|---|
| `ZI_CD_OpsFreshU`, `ZR_CD_OpsFreshness`, `ZC_CD_OpsFreshness` (+ DDLX) | view (UNION), root, projection |
| `ZR_CD_OpsCritExc`, `ZC_CD_OpsCritExc` (+ DDLX) | root, projection |
| `ZC_CD_OPSOVERVIEW` | DCL |
| `ZUI_CD_OPS_OVERVIEW` | service definition (binding `ZUI_CD_OPS_OVERVIEW_O4` in ADT) |
| `ZCL_CD_OPS_OVW_CDS_TEST` | class (test holder): `ltc_freshness` — `one_row_per_monitor_area`, `stale_by_area_threshold`; `ltc_critical` — `open_block_and_error_only`, `overdue_days_are_counted`, `bank_file_message_hidden` |

## 6. VERIFY-ADT

| Item | Fallback |
|---|---|
| UNION of three root views with literal elements | Three list cards (one per as-of entity of the area services) |
| One projection exposed in two service definitions (area + overview) | Copy the KPI / problem projections as `ZC_CD_Ovw*` (same R views) |
| OVP V4 KPI / analytical / list cards from `@UI.chart`, `@UI.dataPoint`, `@UI.selectionVariant`, `@UI.presentationVariant` | Card settings in the manifest (`annotationPath`, `selectionAnnotationPath`) |
| Second data source for the request card | Tile on the Transactions page instead |
| Navigation from a list-card row to another app by area | Card-level navigation only (owned-exceptions app) |

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

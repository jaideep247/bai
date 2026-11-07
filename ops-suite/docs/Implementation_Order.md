# Implementation order — DV1 activation and transport

> **First principle:** activate what others depend on first, and ship each payment engine area as one object set — a runtime switch cannot protect against an inactive class.
> **Analogy:** building a house — foundation (DDIC), walls (interfaces), wiring (classes), then switching the power on (customizing and jobs).

Landscape DV1 → QA1 → PS4. Packages `ZCD_OPS` with sub-packages `ZCD_OPS_CORE`, `ZCD_OPS_EBS`, `ZCD_OPS_FMON`, `ZCD_OPS_HCK`.

**abapGit import (recommended).** The repository carries `/.abapgit.xml` (starting folder `/ops-suite/src/`, folder logic PREFIX) and full abapGit metadata: packages, classes, interfaces, programs with text pools, **all 68 tables** (incl. draft tables and their secondary indexes), CDS / BDEF / DDLX / service definitions of the RAP apps and the message class `ZCD_OPS`. Create the transportable package `ZCD_OPS` in DV1 with the landscape's transport layer, link the repository in abapGit (online: `https://github.com/jaideep247/bai.git`, or offline: `git archive --format=zip -o bai-ops-suite.zip <commit>` → Import ZIP), pull and assign a Workbench request. abapGit activates in dependency order, which replaces most of Steps 1–2 below; use them as the manual fallback and as the checklist for what must be active. Metadata is regenerated with `python3 tools/abapgit_serialize.py`.

**Parameter framework first.** The suite reads every runtime parameter from the global framework `ZCA_PARAM` (`param-framework/`, package `ZCA_PARAM`, own abapGit import from starting folder `/param-framework/src/` — `param-framework/README.md`). Install and activate it **before** the suite (the suite's classes reference `ZIF_CA_PARAM`, `ZCL_CA_PARAM_FACTORY`, `ZCX_CA_PARAM`; the unit tests `ZCL_CA_PARAM_DAO_MEM` / `_BUILDER` / `_INJECTOR`), then register the suite's areas and import its definitions (step 3.0). ZCD_OPS_PARAM no longer exists; it was never deployed, so there is **no migration report** — values are entered in the framework app.

**Pin the revision.** Pull one reviewed commit and record its SHA in the transport description; SAP can only pull what is pushed to the remote (use the offline ZIP otherwise).

**What the pull does not create** (finish in ADT / SAP GUI, capture in the right request):

| Artifact | Where | Step |
|---|---|---|
| Analytical CDS views and access control `ZI_CD_OpsAnalytics` in `ops-suite/cds/` (outside the import folder) | ADT, after the pull | 2.7 |
| Service bindings `ZUI_*_O4` (in-scope apps only, incl. the dashboards `ZUI_CD_FMON_FLOW_O4`, `ZUI_CD_EBS_DASH_O4`, `ZUI_CD_HCK_DASH_O4`, `ZUI_CD_TRX_DASH_O4` and the overview `ZUI_CD_OPS_OVERVIEW_O4`), Fiori apps, launchpad space / pages / catalogs / tiles / target mappings | ADT / launchpad designer | 1a, 1b, 1d, 1e, 1f |
| Request side of the transactions dashboard in `ops-suite/cds/` (`ZI_CD_TrxReqLog` … `ZUI_CD_TRX_REQ`, test class `ZCL_CD_TRX_REQ_CDS_TEST`) — VERIFY-SE11 placeholders | ADT, after SE11 | 1e.6 |
| Authorization object `ZCD_OPS`, field `ZCD_PE_AREA`, roles incl. `S_TABU_NAM` | SU21 / PFCG | 0, 1c.3 |
| Customizing rows (`config/*.csv`, `*_seed.md`) — the pull loads no data | Configuration apps / SM30, customizing request | 3 |
| Parameter areas, definitions and value rows of the suite (`config/param_areas.csv`, `param_definitions.csv`, `param_values.csv`) | Framework app *Parameter areas* (`ZUI_CA_PARAM_O4`), customizing request | 3.0 |
| Job variants and Control-M jobs | SE38 / Control-M | 4 |
| SICF node `/sap/zcd_ops/prism_status` (inactive), PRISM technical user and role `Z_CD_OPS_PRISM`, bgPF / bgRFC inbound destination | SICF / SU01 / PFCG / SBGRFCCONF | 1e |

**Read-only rollout scope.** The suite observes and reports: EBS validation after statement import, posting and payment clearing; FMON; HCK; the payment trace. It never writes FS-CD / FI data and has no posting gate, line release, reprocessing navigation or outbound webhook (removed 2026-11-07; enforcement is a later phase with its own design). Its only writes are its own records — runs, findings, exception history, suppressions, file registry, PRISM evidence. Kept outside the switch-on:
- the **PRISM status API** (step 1e): its table and classes are transported, the SICF node is created **inactive** and the PRISM technical user gets no role — a new callback is outside the read-only rollout and is switched on only as its own CAB-approved change (switch **S-PRISM**).

## Step 0 — Pre-checks (blocking)

| # | Check | Where | Done when |
|---|---|---|---|
| 0.1 | Every `VERIFY-DDIC` marker confirmed or the field adjusted | SE11 — `ZCL_CD_EBS_FEB_DAO`, `ZCL_CD_EBS_SAP_DAO`, `ZCL_CD_FMON_CALENDAR`, `ZCL_CD_HCK_DAO` | Each marker answered in the review record |
| 0.2 | ZCD_ACH_RTRV_LOG status field name (ZZ_RTRV_STATUS / ZZRETRIEVAL_STATUS / ZZ_RTRVL_STATUS — see parity C4) | SE11 | `EBS_RTRV_STATUS_FIELD` value decided |
| 0.3 | Structures of ZCDT_REGUT, ZCD_ACH_ACK, ZCD_WIRE_ACK, ZCD_CHECK_HIST, ZCD_STRP_POUT_LOG | SE11 export | ZCD_FMON_SRC / _SRCMAP rows filled (no `‹SE11›` left in `config/fmon_seed.md`) |
| 0.4 | Each bank's BAI2 / CAMT transaction code sheet | Treasury | ZCD_BTC_MAP bank rows reviewed against `config/zcd_btc_map.csv` |
| 0.5 | Table change logging active (the 23 customizing tables of the suite (incl. ZCD_FMON_DEADL) and the three `ZCA_PARAM_*` tables carry the log flag) | Basis: profile parameter `rec/client` in DV1, QA1, PS4 | SCU3 shows a test change to ZCA_PARAM_VAL in QA1 |
| 0.5a | Parameter framework `ZCA_PARAM` installed and active (package `ZCA_PARAM`, app `ZUI_CA_PARAM_O4`, authorization object `ZCA_PARAM` for the maintainers of areas `CD_*`) | `param-framework/README.md`, `docs/VERIFY.md` there | `ZCL_CA_PARAM_FACTORY=>GET( )` activates; ABAP Unit of the framework green |
| 0.6 | Domain `CCCORACTIV` fixed values confirmed (configuration-app client policy) | SE11 | Values match `ZCL_CD_OPS_CFG_CLIENT` |
| 0.7 | Authorisation object `ZCD_OPS` (field `ZCD_PE_AREA`, data element / domain `ZCD_PE_AREA`) and roles | SE11, SU20, SU21, PFCG — `config/auth_zcd_ops.md` | Batch user holds 16 for EBS, FMON, HCK, CORE; operators and approvers per the role table |

## Step 1 — DDIC (SE11 / ADT)

1. Core: `ZCD_OPS_RUN`, `ZCD_OPS_FINDING` (+ indexes ~OPN, ~OBJ; carry-forward fields FIRST_SEEN_AT, OCCURRENCES, SUPERSEDED_BY, WAIVER_UNTIL), `ZCD_OPS_ALRULE`, `ZCD_OPS_ALCHN`, `ZCD_OPS_ALLOG` (+ index ~RUL), `ZCD_OPS_LOCK` (delivery class L, never written — run-lock argument of `E_TABLE`), `ZCD_OPS_MONCFG` (monitor freshness per area, delivery class C; draft table `ZCD_D_MONCFG`; app entity *Monitor freshness*; seed rows FMON 15, EBS 1560, HCK 1560 — `config/alert_seed.md`; activate before the as-of CDS views, which LEFT OUTER JOIN it).
2. EBS: `ZCD_EBS_RULE_DEF`, `ZCD_BTC_MAP`, `ZCD_BTC_RULE`, `ZCD_EBS_ACCT` (+ index ~ACC), `ZCD_EBS_FLOW_PAT`, `ZCD_EBS_RSN_MAP`, `ZCD_EBS_LOOKUP` (rule R21; draft table `ZCD_D_EBSLKP`).
3. FMON: `ZCD_FMON_IFACE`, `_SLA` (+ ACTIVE, 2026-11-07), `_CAL` (+ ACTIVE), `_DEADL` (stage deadlines, 2026-11-07), `_SRC`, `_SRCMAP`, `_LOTCFG`, `_CHK`, `ZCD_FMON_FILE` (+ unique index IFACE_ID/FILE_REF), `ZCD_FMON_EVENT` (+ unique index SRC_ID/SRC_KEY/STAGE).
4. HCK: `ZCD_HCK_DEF`, `_THRESH`, `_AGG`, `_TABWL`, `_DRIFT`, `ZCD_JOB_CYCLE`, `ZCD_JOB_STEP`, `ZCD_HCK_METRIC`, `ZCD_HCK_BASELINE`.
5. No SM30 maintenance views: every delivery-class-C table is maintained in its RAP configuration app (`RAP_Config_Apps.md`, step 1a).
6. Message class `ZCD_OPS` (262 messages: every user-facing text of the suite) — included in the abapGit pull; manual fallback from `config/zcd_ops_messages.md`. Text pools of the four reports and of `ZCL_CD_HCK_REPORT_HTML` / `ZCL_CD_OPS_ALERT_POLICY` come with the abapGit XML (source `docs/text_elements/`); translate both in SE63.
7a. Technical settings: customizing tables (delivery class C) are delivered **fully buffered**; application tables (A) unbuffered. Secondary indexes are serialized into the abapGit TABL XML (DD12V/DD17V) from the `// @index` lines in `ddic/*/*.tabl.ddl`; after the pull, verify each one in SE11 (step 1c.1) — create it manually only if the pull reports it missing.
7. Application log (SLG0): only needed if a rule uses the APPLOG channel — object `ZCD_OPS`, subobject `ALERT`. No delivered rule writes SLG1 (SLG1 kept to a minimum, 2026-11-07); parameter errors are not logged per run.
8. Authorization object `ZCD_OPS` — step 0.7 (reports, purge and the CDS access role `ZI_CD_OpsAnalytics`).

## Step 1a — RAP configuration apps

Follow `RAP_Config_Apps.md` §6: confirm the VERIFY-ADT items (business-configuration CTS API, UNION ALL in view entities, `delete` as validation trigger), activate in the order given there, create and publish the service bindings `ZUI_CD_EBS_CFG_O4`, `ZUI_CD_FMON_CFG_O4`, `ZUI_CD_HCK_CFG_O4`, `ZUI_CD_OPS_CFG_O4`, add the FLP tiles, and check `rec/client` (step 0.6).

## Step 1b — RAP operations apps

Follow `RAP_Ops_Apps.md` §4: confirm the VERIFY-ADT items (`internal create` on the history association, `READ ENTITIES` in `save_modified`, `RAISE SHORTDUMP`), activate tables → abstract entities `ZA_CD_*` → `ZR_` / `ZC_` views → DDLX → BDEF `ZR_` → behaviour pools → BDEF `ZC_` → service definitions, then create and publish `ZUI_CD_OPS_EXC_O4`, `ZUI_CD_HCK_SUP_O4`, `ZUI_CD_FMON_MAN_O4`, `ZUI_CD_FMON_PRQ_O4`. **Not in this rollout:** `ZUI_CD_EBS_REL_O4` (blocked line releases — pre-posting enforcement, ignored by abapGit). Approver roles (ZCD_OPS 85) go only to users who do not request (segregation of duties).

## Step 1c — Phase 6 prerequisites (audit fixes)

| # | Item | Done when |
|---|---|---|
| 1c.1 | SE11 → Indexes on the 11 indexed tables (20 indexes, generated in the abapGit TABL XML from `// @index` markers; verify each after the pull): ZCD_FMON_FILE REF (unique)/BDT/OUT/NAM/CHK, ZCD_FMON_EVENT SRC (unique), ZCD_FMON_PRISM UNP/REF/BDT, ZCD_FMON_PRQ_WA REF, ZCD_OPS_FINDING OPN/OBJ, ZCD_OPS_EXC_HIST FND, ZCD_OPS_ALLOG RUL and INT (unique), ZCD_OPS_RUN MOD, ZCD_EBS_ACCT ACC, ZCD_HCK_METRIC HST/TIM, ZCD_HCK_SUPPRESS ACT | Every index active after the first pull |
| 1c.2a | BAI processing deadline (user requirement 2026-11-07, `config/fmon_seed.md`): `ZCD_FMON_SRC` row **`FEB`** (IFACE_ID blank, TABLE_NAME FEBKO, ADAPTER_CLASS `ZCL_CD_FMON_ADAPTER_FEB`, ACTIVE X; no SRCMAP / TABWL rows), `ZCD_FMON_DEADL` rows BAI_JPMC_IN / BAI_BOA_IN FULLY_PROCESSED `*` 10:00 E, check row `F_DEADLINE` (`ZCL_CD_FMON_CHK_DEADLINE`), `ZCD_FMON_CAL` NORMAL / HOLIDAY rows of both interfaces, `ACTIVE = X` on every ZCD_FMON_SLA / ZCD_FMON_CAL row, `BANK_KEY` JPMC / BOA on the ZCD_EBS_ACCT rows of the payment engine accounts, ZCA_PARAM `FMON_FEB_STMT_OFFSET` (1 — VERIFY with Treasury), alert rule `FMON_BAIDL` (`config/alert_seed.md`). VERIFY: FEBKO / FEBEP read by the EBS repository (`EBS_FEB_POSTED_FIELDS`, VB1OK / VB2OK) | QA1 FMON-QA-15..19: the 10:00 run raises STAGE_DEADLINE_MISSED with the right condition; a processed day raises nothing |
| 1c.2 | `ZCD_FMON_TABWL` maintained for every table in ZCD_FMON_SRC / ZCD_FMON_LOTCFG (seed list `config/fmon_seed.md`) | Without it every legacy read is refused (PLUGIN_ERROR, message 244) |
| 1c.3 | Role with `S_TABU_NAM` ACTVT 03 for those tables: batch user and online monitor users | No message 245 in a test run |
| 1c.4 | Parameters in ZCA_PARAM (step 3.0): `FMON_AGE_BASIS` (default A), `EBS_ZTNUM_IGNORE_ZEROS`, `EBS_DFKKCR_BUKRS_FIELD`, `EBS_DUP_LOOKBACK_DAYS`, `EBS_FEB_POSTED_FIELDS` (default VB1OK,VB2OK — VERIFY-SE11), `EBS_EMPTY_FEED_OK`, `EBS_INFLIGHT_HOURS` (`config/alert_seed.md`, `EBS_VALIDATION.md` §B5) | Values confirmed with the process owner; VERIFY-DDIC field names checked in SE11 |
| 1c.5 | Seeds: ZCD_EBS_RULE_DEF (NEEDS_POSTING incl. R05, R21, R22, S13; FINDING_CLASS S07 / R09 / R22 = DUPLICATE, S13 = POSTING — the EBS dashboard counts from it), ZCD_BTC_RULE `*` / S13, ZCD_BTC_RULE (166D retrieval-log chain, `*` R22), ZCD_BTC_MAP (DISPOSITION, one canonical wildcard) | Resolver load shows no configuration findings |
| 1c.6 | HCK baselines retaken once after transport (drift hash version 2) | No drift finding caused by the version change |
| 1c.7 | Payment trace (`Payment_Trace.md` §5, §9): SE11 check of every VERIFY-SE11 field (DFKKRAPT, ZCDT_REGUT, ZCD_PAYM_REQ_LOG, ACK tables, ZCD_CHECK_HIST, DFKKOP-AUGRD/PYMET, DFKKKO-STBEL); parameters `TRACE_SRC_REQUEST`, `TRACE_SRC_HISTORY`, `TRACE_SRC_REGUT`, `TRACE_SRC_ACK`, `TRACE_SRC_CHQ_HIST`, `TRACE_BP_SOURCE_FIELD`, `TRACE_MAX_ROWS`, `TRACE_GL_AWTYP`, `TRACE_CHECK_METHODS`, `TRACE_NO_ACK_METHODS`, `TRACE_ACK_NACK_VALUES`, `TRACE_CHQ_FAILED`, `TRACE_BANK_LOOKBACK_DAYS`; `ZCD_FMON_TABWL` rows for DFKKRAPT, BUT000 (if a source field is configured) and every other configured table not yet approved; role with ZCD_OPS 03 (CORE + company codes) and S_TABU_NAM 03 for those tables | A QA1 trace of one ACH, one cheque and one reissued payment shows no SOURCE_NOT_CONFIGURED / SOURCE_NOT_READABLE row |

## Step 1d — File monitoring dashboard (read-only, `Dashboard_File_Monitoring.md`)

| # | Item | Done when |
|---|---|---|
| 1d.1 | Activate (abapGit pull, after the FMON and core tables): `ZI_CD_FmonFlowFile`, `ZI_CD_FmonFileExc`, `ZI_CD_FmonRunLast` → `ZR_CD_FmonAsOf`, `ZR_CD_FmonFlowEvt`, `ZR_CD_FmonFlowFind` → `ZR_CD_FmonFlow` → `ZR_CD_FmonFlowKpi`, `ZR_CD_FmonFlowFail` → the six `ZC_CD_*` projections → metadata extensions → access control `ZC_CD_FMONFLOW` → service definition `ZUI_CD_FMON_FLOW`; then class `ZCL_CD_FMON_FLOW_CDS_TEST` and run its ABAP Unit include. Confirm the VERIFY-ADT list (§10 of the dashboard doc) | All objects active; the 19 CDS tests green |
| 1d.2 | ADT: create service binding **`ZUI_CD_FMON_FLOW_O4`** (binding type OData V4 – UI, service definition `ZUI_CD_FMON_FLOW`), activate, **Publish** (local service endpoint; on-premise also `/IWFND/V4_ADMIN` → publish service group if not auto-published). Preview `FileFlow` in the binding | `$metadata` shows `Aggregation.ApplySupported` on `FileFlow` and `FileFlowKpi`; preview lists files |
| 1d.3 | Fiori elements app (Business Application Studio / VS Code Fiori tools, floorplan **Analytical List Page**, OData V4, main entity `FileFlow`), deploy to the ABAP repository (BSP `ZCD_FMON_FLOW`, package `ZCD_OPS_FMON`), or use the binding's generated app for DV1 | App opens with chart, filter bar and table |
| 1d.4 | Launchpad (`/UI2/FLPD_CUST` or the launchpad app manager): technical catalog `ZCD_OPS_TC_FMON` with the app tile (semantic object **`ZCDFileFlow`**, action `analyze`, target mapping → the deployed app) and the dynamic tiles *Stale monitor*, *Rejected today*, *Unprocessed*, *Breached SLA*, *Missing files* (service URL and `$count` filters in the dashboard doc §6); business catalog `ZCD_OPS_BC_FMON`; group / page in the **Production Support** space | Tiles show counts; a tap opens the dashboard |
| 1d.5 | Roles (PFCG): business role `ZCD_OPS_FMON_DISPLAY` with the business catalog, `S_SERVICE` for `ZUI_CD_FMON_FLOW_O4`, **ZCD_OPS ZCD_PE_AREA = FMON, ACTVT 03**; give it to L1/L2 and team leads (display only — the role grants no 02) | QA FMD-08: a user without FMON 03 sees no row |
| 1d.6 | Optional: `cds/ZI_CD_FmonFlowCube`, `cds/ZC_CD_FmonFlowQry` with step 2.7 (grant in `ZI_CD_OpsAnalytics`) for Analysis for Office | Query opens in RSRT / Analysis for Office |

Not in this step: navigation to the payment trace (proposed — the trace does not accept a file reference yet) the overview page reuses `FileFlowKpi` and `LatestFailure` (step 1f).

## Step 1e — EBS validation, health check and transactions dashboards (read-only)

Same pattern as 1d (`Dashboard_EBS_Validation.md`, `Dashboard_Health_Check.md`, `Dashboard_Transactions.md`). All CDS below comes with the abapGit pull; the order is the activation order abapGit follows (fallback: activate manually in this order).

| # | Item | Done when |
|---|---|---|
| 1e.1 | **Shared (src/core):** `ZI_CD_ReturnItem` (DFKKRP + DFKKRK, RLGRD), `ZI_CD_NocItem` (DFKKNRP, FLGRD, INFOF). Confirm DFKKRP-RLGRD, DFKKNRP-FLGRD, the DFKKRP key and the INFOF format in SE11 first | Both active; SE16 sample matches |
| 1e.2 | **EBS (src/ebs):** `ZI_CD_EbsRunLast` → `ZR_CD_EbsAsOf`; `ZI_CD_EbsRunBase`, `ZI_CD_EbsFinding` → `ZI_CD_EbsRunFind`, `ZI_CD_EbsRunDay`, `ZI_CD_EbsStmtExc`, `ZI_CD_EbsLineExc`; `ZI_CD_EbsLineAcct`, `ZI_CD_EbsAcctNorm` → `ZI_CD_EbsPeAcct` → `ZI_CD_EbsStmtScope` (payment engine scope from XBLNR) → `ZI_CD_EbsStmtBase` → `ZI_CD_EbsLineBase` → `ZI_CD_EbsStmtLines`, `ZI_CD_EbsRetNocU`; roots `ZR_CD_EbsFind`, `ZR_CD_EbsRetNoc` → `ZR_CD_EbsLine` → `ZR_CD_EbsStmt`, `ZR_CD_EbsRun` → `ZR_CD_EbsKpi`, `ZR_CD_EbsProblem` → eight `ZC_CD_Ebs*` → DDLX → DCL `ZC_CD_EBSDASH` → SRVD `ZUI_CD_EBS_DASH`; class `ZCL_CD_EBS_DASH_CDS_TEST` (21 tests) | Active (`REPLACE_REGEXPR` in `ZI_CD_EbsLineAcct`: fallback in `Dashboard_EBS_Validation.md` §9); tests green |
| 1e.3 | **HCK (src/hck):** `ZI_CD_HckRunLast` → `ZR_CD_HckAsOf`; `ZI_CD_HckFinding` → `ZI_CD_HckCheckRes`, `ZI_CD_HckCheckOpen`, `ZI_CD_HckOpenSum`; `ZI_CD_HckMetricBase` → `ZI_CD_HckRunMetric`; roots `ZR_CD_HckFind`, `ZR_CD_HckMetric` → `ZR_CD_HckCheck` → `ZR_CD_HckCategory`, `ZR_CD_HckRed`; `ZR_CD_HckRun`, `ZR_CD_HckKpi` → eight `ZC_CD_Hck*` → DDLX → DCL `ZC_CD_HCKDASH` → SRVD `ZUI_CD_HCK_DASH`; class `ZCL_CD_HCK_DASH_CDS_TEST` (6 tests) | Active; tests green |
| 1e.4 | **Transactions, SAP side (src/core):** `ZI_CD_TrxItem` → `ZI_CD_TrxItemPay`, `…Chq` → `…Enc`, `…Bank`, `…Ret`, `…Noc`, `ZI_CD_TrxRetNocU`; roots `ZR_CD_TrxPayRun`, `ZR_CD_TrxRetNoc` → `ZR_CD_TrxFlow` → `ZR_CD_TrxKpi`, `ZR_CD_TrxProblem` → five `ZC_CD_Trx*` → DDLX → DCL `ZC_CD_TRXDASH` → SRVD `ZUI_CD_TRX_DASH`; class `ZCL_CD_TRX_DASH_CDS_TEST` (8 tests). ST05 / PlanViz at peak (TXD-12) | Active; tests green; runtime recorded |
| 1e.5 | Bindings (OData V4 – UI), activate and **Publish**: **`ZUI_CD_EBS_DASH_O4`**, **`ZUI_CD_HCK_DASH_O4`**, **`ZUI_CD_TRX_DASH_O4`**. Fiori elements apps (ALP): `ZCD_EBS_DASH` (main `EbsStatement`; second app on `EbsFinding`, list report on `EbsRun`), `ZCD_HCK_DASH` (main `HealthCheck`), `ZCD_TRX_DASH` (main `Transaction`; list report on `PaymentRun`) | `$metadata` shows `Aggregation.ApplySupported`; apps open |
| 1e.6 | **After SE11** (transactions part B, `cds/`): replace the VERIFY-SE11 placeholders (`Dashboard_Transactions.md` §4) in `ZI_CD_TrxReqLog`, `ZI_CD_TrxAckU`, `ZI_CD_TrxChqStat`, `ZI_CD_TrxRtrv`; create in ADT `ZI_CD_TrxReqLog` → `ZI_CD_TrxRequest`; `ZI_CD_TrxAckU` → `ZI_CD_TrxAck`; `ZI_CD_TrxChqStat`, `ZI_CD_TrxRtrv`, `ZI_CD_TrxFinFlow` → `ZR_CD_TrxReqFlow` → `ZC_CD_TrxReqFlow` (+ DDLX) → DCL `ZC_CD_TRXREQ` → SRVD `ZUI_CD_TRX_REQ` → binding **`ZUI_CD_TRX_REQ_O4`**; class `ZCL_CD_TRX_REQ_CDS_TEST` (4 tests); app `ZCD_TRX_REQ` | Request funnel and *Errored requests* tile live |
| 1e.7 | Roles: `ZCD_OPS_EBS_DISPLAY` (EBS 03), `ZCD_OPS_HCK_DISPLAY` (HCK 03), `ZCD_OPS_TRX_DISPLAY` (CORE 03 + BUKRS) with catalog and `S_SERVICE` (`config/auth_zcd_ops.md` §3a) | EBD-11, HCD-08, TXD-09 |

## Step 1f — Production-support overview page and launchpad space (`Dashboard_Production_Support.md`)

| # | Item | Done when |
|---|---|---|
| 1f.1 | Activate (pull, after 1d and 1e): `ZI_CD_OpsFreshU` → `ZR_CD_OpsFreshness`, `ZR_CD_OpsCritExc` → `ZC_CD_OpsFreshness`, `ZC_CD_OpsCritExc` → DDLX → DCL `ZC_CD_OPSOVERVIEW` → SRVD `ZUI_CD_OPS_OVERVIEW`; class `ZCL_CD_OPS_OVW_CDS_TEST` (5 tests) | Active; tests green |
| 1f.2 | Binding **`ZUI_CD_OPS_OVERVIEW_O4`** (OData V4 – UI), publish | All ten entity sets in `$metadata` |
| 1f.3 | Fiori elements **overview page** app `ZCD_OPS_OVW` (data source `ZUI_CD_OPS_OVERVIEW_O4`; cards as §1 of the doc); after 1e.6 add `ZUI_CD_TRX_REQ_O4` as second data source with the "Requests" card | Cards render; each card navigates |
| 1f.4 | Launchpad: space **Production Support** (`ZCD_OPS_SP_PROD_SUPPORT`) with pages Overview, File monitoring, EBS validation, Health checks, Transactions, Exceptions; catalogs `ZCD_OPS_TC/BC_OVW`, `_EBS`, `_HCK`, `_TRX`; target mappings (`ZCDOpsOverview-display`, `ZCDEbsValidation-analyze`, `ZCDHealthCheck-analyze`, `ZCDTransaction-analyze`, `ZCDOpsException-manage`; `ZCDPaymentTrace-display` proposed); dynamic tiles of each doc | Space visible for the role; tiles count |
| 1f.5 | Business role `ZCD_OPS_PROD_SUPPORT` (space, catalogs, all `S_SERVICE`, ZCD_OPS 03 for FMON / EBS / HCK / CORE + own BUKRS) | OVP-05 |

## Step 1e — PRISM status API (own approved change, switch S-PRISM; `PRISM_Status_API.md`)

| # | Item | Done when |
|---|---|---|
| 1e.1 | abapGit pull activates `ZCD_FMON_PRISM` (indexes UNP, REF, BDT), `ZIF_CD_FMON_PRISM_TYPES`, `ZIF_/ZCL_CD_FMON_PRISM_DAO`, `ZIF_/ZCL_CD_FMON_PRISM_QUEUE`, `ZCL_CD_FMON_PRISM_OP`, `ZCL_CD_FMON_PRISM_PROC`, `ZCL_CD_FMON_PRISM_EVENT`, `ZCL_CD_FMON_PRISM_API`, `ZCL_CD_FMON_PRISM_HTTP`, `ZCL_CD_FMON_ADAPTER_PRISM`, `ZCL_CD_FMON_CHK_PRISM_FILE` with the FMON group of step 2. **VERIFY-ADT:** `IF_BGMC_OP_SINGLE_TX_UNCONTR`, `CL_BGMC_PROCESS_FACTORY`, `CX_BGMC` exist on SAP_BASIS 7.58 SP01 with the signatures used (`PRISM_Status_API.md` §13); the abaplint stub in `ops-suite/lint_stubs/` is not pulled | All active; ABAP Unit of the PRISM test includes green |
| 1e.2 | **bgPF prerequisites (Basis, per client, VERIFY-ADT against the SAP documentation for 7.58):** SBGRFCCONF — define the bgRFC inbound destination bgPF uses (default destination for background processing / bgPF, with its queue prefix) and the supervisor destination; scheduler active (SBGRFCCONF → scheduler: system / application server); SBGRFCMON shows the destination. Without it `save_for_execution` raises `CX_BGMC` — the API still stores the event (202) and the 5-minute job applies it | A test event's unit appears in SBGRFCMON and ends successfully |
| 1e.3 | SICF (Basis): node `/sap/zcd_ops/prism_status`, handler `ZCL_CD_FMON_PRISM_HTTP`, logon *required* (X.509 client certificate, or basic over TLS), security requirement SSL, SAP authorisation value `ZCD_PRISM`, **no fixed user**, **inactive**; Workbench request (`PRISM_Status_API.md` §10). Not serialized by abapGit (system-specific parent GUID; a pulled node would be active) | Node exists, inactive; transported with the release |
| 1e.4 | Security: technical user `PRISM_FMON` (type B), certificate mapping in STRUST if X.509; role `Z_CD_OPS_PRISM` = `ZCD_OPS` ACTVT 01 / `ZCD_PE_AREA` FMON / `BUKRS` DUMMY + `S_ICF` (ICF_FIELD SERVICE, ICF_VALUE `ZCD_PRISM`) — created, **assigned only at go-live** (`config/auth_zcd_ops.md`) | Role exists; SU53 clean in QA1 |
| 1e.5 | Customizing (`config/fmon_seed.md`): `ZCD_FMON_SRC` row `PRISM` (adapter `ZCL_CD_FMON_ADAPTER_PRISM`), `ZCD_FMON_SRCMAP` RECEIVED / DELIVERED / FAILED, `ZCD_FMON_TABWL` `ZCD_FMON_PRISM`, check rows `F_PRISMRCV`, `F_PRISMDLV`, `F_FILERCV`, `F_PRFAIL`, `F_PRFILE`, PRISM SLA rows of the seeded interfaces; ZCA_PARAM `FMON_PRISM_MAX_BYTES`, `FMON_PRISM_INSTANT`, PRISM throttle `FMON_PRISM_THROTTLE_MIN` (2), `FMON_PRISM_THROTTLE_SCOPE` (A — confirm with the PRISM team), `FMON_PRISM_THROTTLE_METHODS` (ACH,WIRE), `FMON_PRISM_QUEUE_MAX` (30); `PRISM_DELIVERED` SLA rows of ACH / wire interfaces maintained as the base time per file | Rows in the customizing request; the 5-minute run shows no PLUGIN_ERROR for source PRISM |
| 1e.6 | QA1: cases PRISM-01..15 (`Test_and_Validation_Document.md` §6.8) with the PRISM test harness; PRISM's retry policy (§5 of the API document) agreed and tested | Signed off by the PRISM team and payment operations |
| 1e.7 | **Switch S-PRISM** (PS4, after CAB approval of the new integration): assign `Z_CD_OPS_PRISM` to `PRISM_FMON`, activate the SICF node, PRISM enables the calls per flow (`PRISM_Status_API.md` §8). Off again: deactivate the node (PRISM buffers / retries); FMON continues from SAP's own evidence | First events visible in `ZCD_FMON_PRISM` and on the FMON board within seconds |

## Step 2 — Classes, in dependency order (activate each group together)

| Group | Objects |
|---|---|
| 2.1 Core types | `ZIF_CD_OPS_TYPES`, `ZCX_CD_OPS_ERROR` |
| 2.2 Core ports | `ZIF_CD_OPS_STORE`, `ZIF_CD_OPS_CLOCK`, `ZIF_CD_OPS_ALERT`, `ZIF_CD_OPS_ALERT_CHANNEL`, `ZIF_CD_OPS_ALERT_DAO`, `ZIF_CD_OPS_AUTH`, `ZIF_CD_OPS_LOCK`, `ZIF_CD_OPS_PURGE_DAO` |
| 2.3 Core classes | `ZCL_CD_OPS_UTIL`, `ZCL_CD_OPS_CLOCK`, `ZCL_CD_OPS_PARAMS_CA` + `ZCL_CD_OPS_PARAM_SEED` (need ZCA_PARAM, step 0.5a), `ZCL_CD_OPS_STORE`, `ZCL_CD_OPS_ALERT_POLICY`, `ZCL_CD_OPS_ALERT_DAO`, `ZCL_CD_OPS_CHN_EMAIL`, `_APPLOG`, `_HTTP`, `ZCL_CD_OPS_ALERT_ROUTER`, `ZCL_CD_OPS_AUTH`, `ZCL_CD_OPS_LOCK`, `ZCL_CD_OPS_PURGE_DAO`, then **together** `ZCL_CD_OPS_FACTORY` + `ZCL_CD_OPS_INJECTOR` (mutual reference), then `ZCL_CD_OPS_RUN_GUARD`, `ZCL_CD_OPS_PURGE`; `ZCL_CD_OPS_PURGE_DAO` reads ZCD_FMON_EVENT / ZCD_HCK_METRIC, so activate it after step 1.3 / 1.4 |
| 2.3a Core report | `ZCD_OPS_PURGE` (after FMON / HCK tables) |
| 2.3c Patterns | After 2.4 EBS, 2.5 FMON and 2.6 HCK (reads their tables): `ZIF_CD_OPS_PATTERN_TYPES` → `ZCL_CD_OPS_PATTERN_CHECK` → `ZIF_CD_OPS_PATTERN_DAO` → `ZCL_CD_OPS_PATTERN_DAO` → reactivate `ZCL_CD_OPS_FACTORY` + `ZCL_CD_OPS_INJECTOR` → reports `ZCD_OPS_PATTERN_CHECK`, `ZCD_OPS_PATTERN_MIGRATE` (run the migration in step 3.6) |
| 2.3b Payment trace | After 2.4 EBS and 2.5 FMON (reuses their read repositories): `ZIF_CD_OPS_TRACE_TYPES` → `ZIF_CD_OPS_TRACE_DAO` → `ZCL_CD_OPS_TRACE_DAO` → reactivate `ZCL_CD_OPS_FACTORY` + `ZCL_CD_OPS_INJECTOR` → `ZCL_CD_OPS_TRACE_ENGINE` → report `ZCD_OPS_PAYMENT_TRACE` (`Payment_Trace.md`) |
| 2.4 EBS | `ZIF_CD_EBS_TYPES` → other `ZIF_CD_EBS_*` → `ZCL_CD_EBS_FINDING`, `ZCL_CD_EBS_BTC_RESOLVER`, `ZCL_CD_EBS_PE_SCOPE`, DAOs, parsers → `ZCL_CD_EBS_FACTORY` + `ZCL_CD_EBS_INJECTOR` → `ZCL_CD_EBS_RULE_BASE` → 28 `ZCL_CD_EBS_R_*` → sources → `ZCL_CD_EBS_ENGINE` → report `ZCD_EBS_VALIDATE` |
| 2.5 FMON | `ZIF_CD_FMON_TYPES` → other `ZIF_CD_FMON_*` → pure classes (status, rules, query, util) → DAO, DDIC describer, calendar, adapter, lot reader → factory + injector → 9 checks → engine → report `ZCD_FMON_MONITOR` |
| 2.6 HCK | `ZIF_CD_HCK_TYPES` → other `ZIF_CD_HCK_*` → pure classes (stats, threshold, score, cycle_eval, agg_query, param, report_html) → DAO → factory + injector → 11 checks → engine → report `ZCD_MORNING_REPORT` |
| 2.7 CDS | `cds/` (created in ADT, not via abapGit): basic views → cubes → queries → access control `ZI_CD_OpsAnalytics` (incl. `ZI_CD_FmonFlowCube` / `ZC_CD_FmonFlowQry` after step 1d.1); the transactions request side (`ZI_CD_Trx*`, `ZR_/ZC_CD_TrxReqFlow`, `ZUI_CD_TRX_REQ`) only in step 1e.6, after SE11 |

Run each class's ABAP Unit include immediately after activation (Ctrl+Shift+F10), then the full package before releasing the transport.

## Step 3 — Customizing (transport, client-dependent)

0. **Parameters (framework `ZCA_PARAM`).** In the customizing client of DV1, app *Parameter areas* (`ZUI_CA_PARAM_O4`), on one customizing request: (a) register the four areas of `config/param_areas.csv` (`CD_OPS`, `CD_EBS`, `CD_FMON`, `CD_HCK`; owner team, *Editable in production* = X, *Active* = X); (b) enter every row of `config/param_definitions.csv` (92 definitions: kind, value type, min / max, default, allowed pattern, interface, mandatory, developer-owned) — the app refuses an inconsistent row with the same rules the runtime applies; (c) enter the value rows of `config/param_values.csv` that apply to the landscape (SLA days, flags production must be able to switch, time zone …) plus the confirmed `ALERT_MORNING` / `ALERT_DEFAULT` recipient lists; (d) release the request — definitions travel only by transport, values of non developer-owned parameters can later be adjusted in QA1 / PS4 directly (existing rows only, table-logged). Check: after the import run `ZCD_MORNING_REPORT` in test mode — `D_PARAM_INVALID` must report nothing (a missing or invalid definition is a finding the next morning at the latest). A parameter added later follows `DEVELOPMENT_STANDARDS.md` (*Adding a parameter*).
1. Parameter values to confirm per landscape (all in ZCA_PARAM): SLA days, alert recipients as SO23 list names (`ALERT_DEFAULT`, `ALERT_MORNING` = `ZCD_RTBSUP`), EBS/FMON/HCK parameters (see payment engine area docs; names in each area's `gc_param`, defaults in the definitions; HCK row caps `HCK_MAX_JOB_ROWS` / `_JOB_NAMES` / `_AGG_ROWS`).
1. `ZCD_OPS_MONCFG` (app *Alerting and monitor freshness* → *Monitor freshness*): FMON 15, EBS 1560, HCK 1560 minutes (`config/alert_seed.md`) — dashboards and morning report self-check read the same row.
2. **SO23 first, in each client (DV1, QA1, PS4):** create the shared distribution lists of `config/alert_seed.md` (`ZCD_PAYOPS`, `ZCD_RETOPS`, `ZCD_COMPL`, `ZCD_RTBSUP`, `ZCD_RTBLEAD` — names as confirmed) and add their members; SO23 lists are not transported. Then `ZCD_OPS_ALCHN` and `ZCD_OPS_ALRULE` from `config/alert_seed.md` (e-mail and application-log channels) — the app refuses an e-mail destination that is not a shared SO23 list (419).
3. EBS: load `config/zcd_ebs_rule_def.csv`, `zcd_btc_map.csv`, `zcd_btc_rule.csv`, `zcd_ebs_rsn_map.csv` (payment engine reasons filled by the returns team); `ZCD_EBS_ACCT` per house bank account with **ACCOUNT_NO = the 10-character payment engine bank account as it appears in FEBEP-XBLNR after the bank text** (e.g. XBLNR `JPMC8XX1174412334` → `8XX1174412`; upper case, no leading blank) and ACTIVE = X. Only statements whose every line carries an active ACCOUNT_NO are validated and shown on the EBS dashboard (`EBS_VALIDATION.md` §A0a) — collect the list of payment engine accounts per bank from Treasury and check it against a FEBEP sample (SE16, XBLNR of the last statement of each account) before the first productive run.
4. FMON: `config/fmon_seed.md` once step 0.3 is done.
5. HCK: `config/hck_seed.md` (job names from the Control-M export, not the wiki placeholders).
6. **Patterns to PCRE (once, after the pull, before scheduling the monitors in step 4).** Run `ZCD_OPS_PATTERN_MIGRATE` in test mode, review INVALID / TOO_LONG / ALREADY_PCRE rows, then update mode with the customizing request (`Operations_Runbook.md` §5e); seeds of `config/*_seed.md` are already PCRE. Check each area with `ZCD_OPS_PATTERN_CHECK`. In QA1 / PS4 run update mode once more for ZCD_HCK_SUPPRESS only (application data). Until then a remaining CP wildcard such as `ZCD_*` is invalid PCRE and is reported (PATTERN_INVALID / E373 / FLOW_PATTERN_INVALID / alert rule logged failed), not silently ignored.

## Step 4 — Jobs (native SAP jobs; EBS chained in Control-M)

**Scheduling decision (2026-11-06).** The suite's own monitors are SAP-internal and owned by the SAP support team, so they run as **native SAP periodic jobs (SM36)**: file monitoring every 5 minutes, the morning report daily, purge monthly. Only `ZCD_EBS_VALIDATE` stays in **Control-M**, because it must start after the statement import, posting and payment clearing jobs that Control-M schedules. PRISM status API calls are processed on arrival by a background unit (bgPF), so PRISM milestones do not wait for the 5-minute run. Trade-off: a native job cannot report that SAP background processing itself has stopped; the morning report's health-of-health check (last run per payment engine area) and Basis monitoring cover that.

| Job | Program / variant | When |
|---|---|---|
| ZCD_EBS_VALIDATE_ALL | `ZCD_EBS_VALIDATE`, FEB source, yesterday–today, test mode off | After each BAI load (JPMC/BOA 8:20 am cycle) **once the statement import, the posting job (FEBP) and the payment clearing job have completed** — a post-posting detective control (operating model 2026-11-06); a Control-M dependency on those three jobs, not a clock time (predecessors below) |
| ZCD_FMON_MONITOR_ALL | `ZCD_FMON_MONITOR`, business date today | **SM36 periodic job, every 5 min**, around the clock or 4 am – 8 pm per the payment windows (an overlapping start is refused with RUN_LOCKED; must finish well within 5 min — measure at gate 3) |
| ZCD_MORNING_REPORT | `ZCD_MORNING_REPORT`, all categories, e-mail on | **SM36 daily job**, 6:45 am, after the overnight cycle and before business hours |
| ZCD_OPS_PURGE_MONTHLY | `ZCD_OPS_PURGE`, test mode off | **SM36 monthly job**, outside the payment windows (first Sunday, 3 am) |

**Control-M predecessors of ZCD_EBS_VALIDATE_ALL (operating model 2026-11-06).** Define in-conditions, per bank cycle, on the successful end (OK) of:

| Order | Predecessor (take the names from the Control-M schedule export, `JQ4SP*` / SAP job `ZCD_<function>_<ENTITY>`) | What it does |
|---|---|---|
| 1 | Bank statement import (FF_5 / the import variant of the cycle) | FEBKO / FEBEP rows |
| 2 | Bank statement posting (FEBP) | Posting areas 1 / 2 — FEBEP-VB1OK / VB2OK (VERIFY-SE11), FEBEP-BELNR |
| 3 | Payment clearing job of the cycle | Clearing, returns lots, DPAYH status |

The predecessors are parsed from free-text comments in the schedule export — absence of a dependency there does not prove independence; confirm the chain with the job owners. If the validation starts before a predecessor finished, the run reports **POSTING_INCOMPLETE** and does not evaluate the posting-dependent rules for the unposted lines (never a false pass or a false failure); a Control-M rerun after the predecessors is idempotent (`Operations_Runbook.md` §5c). Do not add the reverse dependency: nothing waits for the validation.

**Batch server group and runtime limits (Basis, before gate 3).** Run the three suite jobs and the purge on a dedicated batch server group — RZ12 (logon / RFC server groups) for the group, SM61 job server group `ZCD_OPS` naming the application servers and their background work processes — and set it as the *target server group* of each job (SM36 *Exec. target*; for the Control-M EBS job in its SAP job definition). Keep the group off the servers that carry the FS-CD mass runs (FPY1, FPVA, FPVB, FP09, FPB7, FEBP) so the suite never competes for their background work processes; schedule job class C. Limit runtime (Control-M max-runtime alert for EBS, 60 min; for the native jobs the morning report's stale-run and job-runtime checks, e.g. 4 min for the FMON cycle, 60 min for the morning report) — the run lock (RUN_LOCKED) stops overlapping starts, the stale-run check of the morning report shows a hung run.

**No locks on standard tables.** The suite only reads FS-CD / FI tables (DFKKOP, DPAYH, DFKKCR, DFKKRP, FEBKO / FEBEP, BSEG, ACDOCA …) with Open SQL `SELECT`; it takes no ENQUEUE on them and never writes them. On SAP HANA a read sees committed data without read locks (MVCC), so a running FEBP / FPY1 is neither blocked nor slowed by a suite run. The only lock the suite takes is its own run lock (`E_TABLE` on `ZCD_OPS_LOCK`, client + payment engine area + variant).

## Step 5 — Rollback

Deactivate the jobs (SM36 periodic jobs and the Control-M EBS job). No standard object is modified and the suite writes only its own tables, so removing the jobs returns the system to its previous behaviour. Duration: under 15 minutes.

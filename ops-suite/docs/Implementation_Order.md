# Implementation order — DV1 activation and transport

> **First principle:** activate what others depend on first, and ship each module as one object set — a runtime switch cannot protect against an inactive class.
> **Analogy:** building a house — foundation (DDIC), walls (interfaces), wiring (classes), then switching the power on (customizing and jobs).

Landscape DV1 → QA1 → PS4. Packages `ZCD_OPS` with sub-packages `ZCD_OPS_CORE`, `ZCD_OPS_EBS`, `ZCD_OPS_FMON`, `ZCD_OPS_HCK`.

**abapGit import (recommended).** The repository carries `/.abapgit.xml` (starting folder `/ops-suite/src/`, folder logic PREFIX) and full abapGit metadata: packages, classes, interfaces, programs, **all 30 tables** and the message class `ZCD_OPS`. Create package `ZCD_OPS` in DV1, link the repository in abapGit, pull. abapGit activates in dependency order, which replaces most of Steps 1–2 below; use them as the manual fallback and as the checklist for what must be active. Metadata is regenerated with `python3 tools/abapgit_serialize.py`.

## Step 0 — Pre-checks (blocking)

| # | Check | Where | Done when |
|---|---|---|---|
| 0.1 | Every `VERIFY-DDIC` marker confirmed or the field adjusted | SE11 — `ZCL_CD_EBS_FEB_DAO`, `ZCL_CD_EBS_SAP_DAO`, `ZCL_CD_FMON_CALENDAR`, `ZCL_CD_HCK_DAO` | Each marker answered in the review record |
| 0.2 | ZCD_ACH_RTRV_LOG status field name (ZZ_RTRV_STATUS vs ZZRETRIEVAL_STATUS) | SE11 | `EBS_RTRV_STATUS_FIELD` value decided |
| 0.3 | Structures of ZCDT_REGUT, ZCD_ACH_ACK, ZCD_WIRE_ACK, ZCD_CHECK_HIST, ZCD_STRP_POUT_LOG | SE11 export | ZCD_FMON_SRC / _SRCMAP rows filled (no `‹SE11›` left in `config/fmon_seed.md`) |
| 0.4 | BAdI FIEB_CHANGE_BS_DATA method signature | SE18 | Copied into the BAdI design (not delivered here) |
| 0.5 | Each bank's BAI2 / CAMT transaction code sheet | Treasury | ZCD_BTC_MAP bank rows reviewed against `config/zcd_btc_map.csv` |

## Step 1 — DDIC (SE11 / ADT)

1. Core: `ZCD_OPS_PARAM`, `ZCD_OPS_RUN`, `ZCD_OPS_FINDING` (+ indexes ~OPN, ~OBJ), `ZCD_OPS_ALERT_RULE`, `ZCD_OPS_ALERT_CHN`, `ZCD_OPS_ALERT_LOG` (+ index ~RUL).
2. EBS: `ZCD_EBS_RULE_DEF`, `ZCD_BTC_MAP`, `ZCD_BTC_RULE`, `ZCD_EBS_ACCT` (+ index ~ACC), `ZCD_EBS_FLOW_PAT`, `ZCD_EBS_RSN_MAP`.
3. FMON: `ZCD_FMON_IFACE`, `_SLA`, `_CAL`, `_SRC`, `_SRCMAP`, `_LOTCFG`, `_CHK`, `ZCD_FMON_FILE` (+ unique index IFACE_ID/FILE_REF), `ZCD_FMON_EVENT` (+ unique index SRC_ID/SRC_KEY/STAGE).
4. HCK: `ZCD_HCK_DEF`, `_THRESH`, `_AGG`, `_TABWL`, `_DRIFT`, `ZCD_JOB_CYCLE`, `ZCD_JOB_STEP`, `ZCD_HCK_METRIC`, `ZCD_HCK_BASELINE`.
5. Table maintenance generator (SM30) for every delivery-class-C table; authorization group `ZCD_OPS`.
6. Message class `ZCD_OPS` (50 messages) — included in the abapGit pull; manual fallback from `config/zcd_ops_messages.md`.
7a. Technical settings: customizing tables (delivery class C) are delivered **fully buffered**; application tables (A) unbuffered. Secondary indexes are not in the abapGit XML — create them from the comments in `ddic/*/*.tabl.ddl`.
7. Application log object/subobject `ZCD_OPS` / `ALERT` (SLG0) for the APPLOG channel.
8. Authorization object `ZCD_OPS` (used by the CDS access role `ZI_CD_OpsAnalytics`).

## Step 2 — Classes, in dependency order (activate each group together)

| Group | Objects |
|---|---|
| 2.1 Core types | `ZIF_CD_OPS_TYPES`, `ZCX_CD_OPS_ERROR` |
| 2.2 Core ports | `ZIF_CD_OPS_STORE`, `ZIF_CD_OPS_CLOCK`, `ZIF_CD_OPS_ALERT`, `ZIF_CD_OPS_ALERT_CHANNEL`, `ZIF_CD_OPS_ALERT_DAO` |
| 2.3 Core classes | `ZCL_CD_OPS_UTIL`, `ZCL_CD_OPS_CLOCK`, `ZCL_CD_OPS_STORE`, `ZCL_CD_OPS_ALERT_POLICY`, `ZCL_CD_OPS_ALERT_DAO`, `ZCL_CD_OPS_CHN_EMAIL`, `_APPLOG`, `_HTTP`, `ZCL_CD_OPS_ALERT_ROUTER`, then **together** `ZCL_CD_OPS_FACTORY` + `ZCL_CD_OPS_INJECTOR` (mutual reference) |
| 2.4 EBS | `ZIF_CD_EBS_TYPES` → other `ZIF_CD_EBS_*` → `ZCL_CD_EBS_FINDING`, `ZCL_CD_EBS_BTC_RESOLVER`, DAOs, parsers → `ZCL_CD_EBS_FACTORY` + `ZCL_CD_EBS_INJECTOR` → `ZCL_CD_EBS_RULE_BASE` → 26 `ZCL_CD_EBS_R_*` → sources → `ZCL_CD_EBS_ENGINE` → report `ZCD_EBS_VALIDATE` |
| 2.5 FMON | `ZIF_CD_FMON_TYPES` → other `ZIF_CD_FMON_*` → pure classes (status, rules, query, util) → DAO, DDIC describer, calendar, adapter, lot reader → factory + injector → 9 checks → engine → report `ZCD_FMON_MONITOR` |
| 2.6 HCK | `ZIF_CD_HCK_TYPES` → other `ZIF_CD_HCK_*` → pure classes (stats, threshold, score, cycle_eval, agg_query, param, report_html) → DAO → factory + injector → 11 checks → engine → report `ZCD_MORNING_REPORT` |
| 2.7 CDS | `cds/` (created in ADT, not via abapGit): basic views → cubes → queries → access control `ZI_CD_OpsAnalytics` |

Run each class's ABAP Unit include immediately after activation (Ctrl+Shift+F10), then the full package before releasing the transport.

## Step 3 — Customizing (transport, client-dependent)

1. `ZCD_OPS_PARAM`: SLA days, alert recipients (`ALERT_DEFAULT`, `ALERT_MORNING`), EBS/FMON/HCK parameters (see module docs).
2. `ZCD_OPS_ALERT_CHN` and `ZCD_OPS_ALERT_RULE` from `config/alert_seed.md` (HTTP channel inactive until Basis creates the SM59 destination).
3. EBS: load `config/zcd_ebs_rule_def.csv`, `zcd_btc_map.csv`, `zcd_btc_rule.csv`, `zcd_ebs_rsn_map.csv` (FI-CA reasons filled by the returns team); `ZCD_EBS_ACCT` per house bank account.
4. FMON: `config/fmon_seed.md` once step 0.3 is done.
5. HCK: `config/hck_seed.md` (job names from the Control-M export, not the wiki placeholders).
6. TVARVC `ZCD_EBS_VALIDATION_MODE` = `M` (monitor) for go-live; `E` only after the QA1 shadow run is signed off.

## Step 4 — Jobs (Control-M)

| Job | Program / variant | When |
|---|---|---|
| ZCD_EBS_VALIDATE_ALL | `ZCD_EBS_VALIDATE`, FEB source, yesterday–today, test mode off | After each BAI load (JPMC/BOA 8:20 am cycle) |
| ZCD_FMON_MONITOR_ALL | `ZCD_FMON_MONITOR`, business date today | Every 30 min, 4 am – 8 pm (one at a time — no run lock) |
| ZCD_MORNING_REPORT | `ZCD_MORNING_REPORT`, all categories, e-mail on | 6:45 am, after the overnight cycle and before business hours |

## Step 5 — Rollback

Deactivate the jobs (Control-M) and set `ZCD_EBS_VALIDATION_MODE` = `O`. No standard object is modified and the BAdI is not part of this delivery, so removing the jobs returns the system to its previous behaviour. Duration: under 15 minutes.

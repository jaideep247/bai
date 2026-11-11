# ZCA_OPS - cross-application operations framework

A reusable framework for SAP operations checks on S/4HANA 2023, SAP_BASIS 7.58, classic ABAP. A
**consumer** (a team's monitoring, validation or health check) runs **checks** in its **area**,
writes their **findings** into one auditable store, and the framework turns findings of severity
B / E / W into owned **exceptions** with an SLA due date, raises **alerts** by configurable rules,
guards runs with a lock and an abort boundary, gates its configuration apps by client role and
transport, and purges its history by retention.

The source lives in the repository `jaideep247/bai`, folder `ops-framework/` (this folder is the
framework root; every path below is relative to it). It was extracted on 2026-11-10 from its first
consumer, which now consumes it like any other. The framework needs nothing of a consumer: it ships
with the parameter framework (`../param-framework`) and the shared offline tools (`../tools/abaptools`).

## Install order

**ZCA_PARAM -> ZCA_OPS -> consumer.** The framework depends only on the parameter framework
ZCA_PARAM (`param-framework/`, release 1.1.0 or later - checked at runtime, message 044) and SAP
standard. Both components stay separate and are shipped together (user decision 2026-11-10).

| Piece | Objects |
|---|---|
| Store | `ZIF_CA_OPS_STORE` / `ZCL_CA_OPS_STORE`, tables `ZCA_OPS_RUN`, `ZCA_OPS_FINDING` (with the company code of a finding, `BUKRS`, blank = area-level - company-code isolation, `docs/auth_zca_ops.md` §3c), `ZCA_OPS_EXC_HIST` |
| Exceptions | `ZIF_CA_OPS_EXC_DAO` / `ZCL_CA_OPS_EXC_DAO`, `ZCL_CA_OPS_EXC_POLICY`, `ZIF_CA_OPS_EXC_TYPES`; app `ZUI_CA_OPS_EXC` (RAP BO `ZR_CA_OpsException`, sub-package `ZCA_OPS_UI`; actions assign, resolve, request / approve waiver, **classify** - reason code of an open exception, `ZCA_OPS_FINDING-REASON_CODE`, values `EXC_REASON_CODES`, carried forward) |
| Alerting | `ZIF_CA_OPS_ALERT` / `ZCL_CA_OPS_ALERT_ROUTER`, `ZCL_CA_OPS_ALERT_POLICY`, `ZIF_CA_OPS_ALERT_DAO` / `ZCL_CA_OPS_ALERT_DAO`, channels `ZIF_CA_OPS_ALERT_CHANNEL` (`ZCL_CA_OPS_CHN_EMAIL`, `ZCL_CA_OPS_CHN_APPLOG`), consumer sections `ZIF_CA_OPS_ALERT_SECTION`; tables `ZCA_OPS_ALRULE`, `ZCA_OPS_ALCHN`, `ZCA_OPS_ALLOG` |
| Alert e-mail templates | `ZIF_CA_OPS_MAIL_TEMPLATE`, `ZCL_CA_OPS_MAIL_TPL_SMTG` (SAP e-mail templates), `ZCL_CA_OPS_MAIL_TPL_BUILTIN` (built-in layout, fallback), `ZCL_CA_OPS_MAIL_COMPOSER`; data source `ZI_CA_OPS_ALERTMAILCTX`; generic template `ZCA_OPS_ALERT_DEFAULT` (`templates/`, documented source) - `docs/ALERT_TEMPLATES.md` |
| Run control | `ZIF_CA_OPS_LOCK` / `ZCL_CA_OPS_LOCK` (lock argument `ZCA_OPS_LOCK`), `ZCL_CA_OPS_RUN_GUARD` (refuse / abort) |
| Configuration apps | gate `ZCL_CA_OPS_CFG_GATE` (+ `_CLIENT`, `_TRANSPORT`, `_AUTH`, `_POLICY`, `_FACTORY`, `_INJECTOR`, `ZIF_CA_OPS_CFG_*`), field checks `ZCL_CA_OPS_CFG_CHECKS`; app `ZUI_CA_OPS_CFG` (alert rules, channels, purge targets, controls and their checks and guidance; generated) |
| Control register and daily review | tables `ZCA_OPS_CONTROL`, `ZCA_OPS_CTLT` (guidance per language), `ZCA_OPS_CTLCHK` (checks a control covers) in `ZUI_CA_OPS_CFG`; sign-off `ZCA_OPS_REVIEW`; review app `ZUI_CA_OPS_REV` (RAP BO `ZR_CA_OpsCtlReview`, action *Mark reviewed*); status per business date derived in CDS from the findings (`ZI_CA_OpsCtlFind` ... `ZI_CA_OpsCtlState`), never stored; `ZCL_CA_OPS_REVIEW_POLICY`, `ZIF_CA_OPS_REVIEW_DAO` / `ZCL_CA_OPS_REVIEW_DAO`, `ZIF_CA_OPS_CTL_TYPES`, domain `ZCA_OPS_CTL_STATUS` - `docs/CONTROL_REVIEW.md` |
| Process onboarding (2026-11-10) | contract `ZIF_CA_OPS_CHECK` and generic runner `ZCL_CA_OPS_CHECK_RUNNER` / report `ZCA_OPS_CHECK_RUN` (one job per area and schedule group); process register `ZCA_OPS_PROC`, check registry `ZCA_OPS_CHECK`; no-code aggregate check `ZCL_CA_OPS_CHK_AGG` (`ZCA_OPS_AGG` over tables approved per area in `ZCA_OPS_TABWL`, builder `ZCL_CA_OPS_AGG_QUERY`: COUNT / AGE per company code, amber / red); onboarding check `ZCL_CA_OPS_CHK_ONBOARD`; `ZIF_CA_OPS_CHECK_DAO` / `ZCL_CA_OPS_CHECK_DAO`, `ZIF_CA_OPS_CHK_TYPES`; area dashboard `ZUI_CA_OPS_DASH` (`ZR_CA_OpsCheckStatus`, freshness `CHECK_STALE_MIN_<area>`) - `docs/ADDING_A_BUSINESS_PROCESS.md` |
| SAP job monitor (2026-11-11) | registered checks `ZCL_CA_OPS_CHK_JOB_FAIL` / `ZCL_CA_OPS_CHK_JOB_STATE`, engine `ZCL_CA_OPS_JOB_MONITOR`, `ZIF_CA_OPS_JOB_DAO` / `ZCL_CA_OPS_JOB_DAO`, job log `ZIF_CA_OPS_JOB_LOG` / `ZCL_CA_OPS_JOB_LOG` / `ZCL_CA_OPS_JOB_LOG_CACHE`, resolvers `ZIF_CA_OPS_JOB_RESOLVER` (`ZCL_CA_OPS_JOB_RES_FIELD`, `_EVENT`, `_JOBLOG`, `_HEUR`), plug-ins `ZIF_CA_OPS_JOB_ENRICHER`, `ZIF_CA_OPS_JOB_CLAIM`, `ZCL_CA_OPS_JOB_TIME`, `ZIF_CA_OPS_JOB_TYPES`; tables `ZCA_OPS_JOB`, `_JOBSTEP`, `_JOBMSG`, `_JOBALOG`, `_JOBBO`, `_JOBWM`, `_JOBSCH`; purge target `ZCL_CA_OPS_JOB_PURGE`; board `ZUI_CA_OPS_JOBS` - `docs/JOB_MONITORING.md` |
| Operations response features (2026-11-11) | runbook link per check `ZCA_OPS_RUNBOOK` (CDS `ZI_CA_OpsFindRunbook`); planned downtime windows `ZCA_OPS_DTWIN` (app `ZUI_CA_OPS_DTW`, four-eyes; API `ZIF_CA_OPS_DOWNTIME` / `ZCL_CA_OPS_DOWNTIME`, `ZCL_CA_OPS_DOWNTIME_POLICY`; finding mark, alert log D); escalation until acknowledged (`ZCA_OPS_ALRULE-ESC_*`, report `ZCA_OPS_ESCALATE`); alert correlation `ZCA_OPS_CORR` (`ZCL_CA_OPS_CORRELATOR`; parent alerted with its children's count, log K); response-time metrics MTTA / MTTR (`ZUI_CA_OPS_MET`); shift handover (`ZUI_CA_OPS_HOVR`); `ZIF_CA_OPS_RESP_TYPES` - `docs/OPERATIONS_FEATURES.md` |
| Link registry (2026-11-11) | layered model of business objects, their fields and the links between them - product baseline `S4CORE` (S/4HANA core standard, released views), industry package `FICA` (SAP FI-CA / FS-CD standard tables), a customer's overlay on top (custom tables, custom fields on standard tables, own links, switch-off and replacement of standard links): tables `ZCA_OPS_LNKLYR`, `_LNKOBJ`, `_LNKFLD`, `_LINK`, `_LNKCND`, `_LNKACT` in `ZUI_CA_OPS_CFG`; drill-down `ZIF_CA_OPS_LINK_WALKER` / `ZCL_CA_OPS_LINK_WALKER` (bounded, set-based, read only, approved tables, masked keys); `ZCL_CA_OPS_LINK_REGISTRY`, `_LINK_QUERY`, `ZIF_CA_OPS_LINK_DAO` / `ZCL_CA_OPS_LINK_DAO`, registry check `ZCL_CA_OPS_CHK_LINKS`, `ZIF_CA_OPS_LINK_TYPES`; offline engine `tools/link_registry.py` (seed rows, lineage, CDS snippets, impact; payment model joins from the registry) - `docs/LINK_REGISTRY.md` |
| Process catalogue (2026-11-11) | SAP standard processes in layered packages - product baseline `S4CORE`, industry packages `FICA` (SAP FI-CA) and `FSCD` (SAP FS-CD), a customer layer on top - with steps (transactions, programs, mass activities), standard tables (link registry objects), dependencies and inactive monitoring templates; **activation per customer** effective from a date with reason and approver (`ZCA_OPS_CATPKG` / `_CATPRC` / `_CATSTP` / `_CATTAB` / `_CATDEP` / `_CATACT` in `ZUI_CA_OPS_CFG`; `ZCA_OPS_PROC-CAT_PROCESS`); API `ZIF_CA_OPS_CATALOG` / `ZCL_CA_OPS_CATALOG`; the runner skips checks of processes not in effect, the area dashboard and the review show only active processes (`ZC_CA_OpsProcStatus`, `ZC_CA_OpsCatalogue`); generic risk checks (write-off limit / reason, `ZCL_CA_OPS_CHK_OUTAGE`); offline engine `tools/process_catalogue.py` (`docs/PROCESS_CATALOGUE.md`) |
| Retention purge | `ZCL_CA_OPS_PURGE`, `ZIF_CA_OPS_PURGE_DAO` / `ZCL_CA_OPS_PURGE_DAO`, targets `ZIF_CA_OPS_PURGE_TARGET`, registry `ZCA_OPS_PURGE`, report `ZCA_OPS_RETENTION` (built-in targets RUN, ALERT_LOG, REVIEW, DOWNTIME) |
| Utilities | `ZIF_CA_OPS_TYPES`, `ZCX_CA_OPS_ERROR` (message class `ZCA_OPS`), `ZCL_CA_OPS_UTIL`, `ZCL_CA_OPS_CLOCK`, `ZCL_CA_OPS_FILE_PATH`, `ZCL_CA_OPS_AUTH` (object `ZCA_OPS`), `ZIF_CA_OPS_PARAMS` / `ZCL_CA_OPS_PARAMS` (adapter over ZCA_PARAM), `ZCL_CA_OPS_FACTORY` / `ZCL_CA_OPS_INJECTOR`, `ZCL_CA_OPS_PARAM_SEED` (generated, tests) |

## Install with abapGit

Package `ZCA_OPS` (sub-packages `ZCA_OPS_UI` from folder `src/ui` and the optional demo `ZCA_OPS_DEMO` from
`src/demo`), folder logic PREFIX, starting folder `/src/` of this folder (`/ops-framework/src/` of the
repository, see `.abapgit.xml`). **Step by step for a new customer, with the checklist before the first pull
(name clashes on the prefix `ZCA`, reuse rights): `docs/INSTALL.md`.**

- **Offline ZIP**: in a clone of `jaideep247/bai` run
  `git archive HEAD:ops-framework --format=zip -o zca_ops.zip` (without the demo:
  `zip -d zca_ops.zip 'src/demo/*'`), then in abapGit *New Offline* -> package `ZCA_OPS` -> *Import ZIP* -> *Pull*.
- After the pull: register area `CA_OPS` and the definitions of `config/param_definitions.csv` in the
  ZCA_PARAM app (`ZUI_CA_PARAM_O4`), create the service bindings `ZUI_CA_OPS_EXC_O4` and
  `ZUI_CA_OPS_CFG_O4` and `ZUI_CA_OPS_REV_O4` and `ZUI_CA_OPS_DASH_O4` and `ZUI_CA_OPS_JOBS_O4` and `ZUI_CA_OPS_DTW_O4`, `ZUI_CA_OPS_MET_O4`,
  `ZUI_CA_OPS_HOVR_O4` (OData V4 - UI), schedule `ZCA_OPS_ESCALATE` per area where rules escalate by time, create the SLG0 object `ZCA_OPS` / sub-object `ALERT` when
  a rule uses the APPLOG channel, run ABAP Unit and ATC, run the demo report `ZCA_OPS_DEMO`, work through
  `docs/VERIFY.md`.

| Demo (optional, not for production) | Objects |
|---|---|
| Sub-package `ZCA_OPS_DEMO` | report `ZCA_OPS_DEMO`, `ZCL_CA_OPS_DEMO` (the consumer: run, findings, alerts), `ZIF_CA_OPS_DEMO_DAO` / `ZCL_CA_OPS_DEMO_DAO` (job counts of `TBTCO`, read only), `ZIF_CA_OPS_DEMO_TYPES`; messages 900-903 of `ZCA_OPS`; seed rows `config/demo/` (area `CA_DEMO`, channel APPLOG, rule `DEMO_LOG`) |

## How a consumer uses it

A consumer is any team's check, monitor or report; it references only `ZCA_*` objects and SAP standard
(the demo `src/demo/zcl_ca_ops_demo.clas.abap` is a complete example in 200 lines, with its unit test).

1. **Register an area.** The area is a parameter area of ZCA_PARAM (one area register,
   `ZCA_PARAM_AREA`, at most 16 characters, e.g. `ZXX_OPS`) - enter it in the parameter app. Every run,
   finding, alert rule, lock and authorisation of the consumer names it; `start_run` refuses an unknown or
   inactive area (message 043). Give users object `ZCA_OPS` with `ZCA_PARAR` = the area
   (`docs/auth_zca_ops.md`) and check it before a run:

```abap
zcl_ca_ops_factory=>get_auth( )->check( iv_activity = zif_ca_ops_auth=>gc_activity-execute
                                        iv_area     = gc_area ).          " raises 041 when not allowed
```

2. **Read parameters** through `ZCL_CA_OPS_FACTORY=>GET_PARAMS( )`; pass `iv_area` or register the
   consumer's name prefixes once with `ADD_PREFIXES` (the longest prefix decides the area):

```abap
DATA(lo_params) = zcl_ca_ops_factory=>get_params( ).
DATA(lv_days) = lo_params->get_param( iv_name = 'ZXX_LOOKBACK_DAYS' iv_area = gc_area iv_default = `7` ).
```

3. **Write findings.** Start the run, make it durable, write the findings (B / E / W become exceptions
   with an owner and an SLA due date, I is information), resolve what is no longer raised, finish, commit,
   then let the alert rules decide who hears about it. A technical error closes the run as aborted.

```abap
DATA(lo_store) = zcl_ca_ops_factory=>get_store( ).
DATA(ls_run) = lo_store->start_run( iv_area = gc_area iv_variant = 'DAILY' iv_test_mode = p_test ).
lo_store->commit( ).                          " durable before notified
TRY.
    DATA(lt_findings) = VALUE zif_ca_ops_types=>tt_finding(
      ( object_type = 'DOC' object_key = lv_key rule_id = 'R01' check_code = 'AMOUNT_MISMATCH'
        severity = zif_ca_ops_types=>gc_severity-error action = zif_ca_ops_types=>gc_action-exception
        message = zcl_ca_ops_util=>message_text( iv_msgid = gc_message_class iv_msgno = '001' iv_v1 = lv_key ) ) ).
    lo_store->save_findings( EXPORTING it_findings = lt_findings CHANGING cs_run = ls_run ).
    lo_store->reconcile( is_run = ls_run it_object_keys = lt_keys_evaluated ).   " auto-resolve
    ls_run-rag      = zcl_ca_ops_util=>rag_from_findings( lt_findings ).
    ls_run-status   = zif_ca_ops_types=>gc_run_status-success.          " or warning / error
    ls_run-ended_at = zcl_ca_ops_factory=>get_clock( )->now( ).
    lo_store->finish_run( ls_run ).
    lo_store->commit( ).
    zcl_ca_ops_factory=>get_alert( )->dispatch( is_run = ls_run it_findings = lt_findings ).
  CATCH zcx_ca_ops_error INTO DATA(lx_error).  " covers the consumer's subclass too
    zcl_ca_ops_run_guard=>abort( EXPORTING ix_error = lx_error CHANGING cs_run = ls_run ).
    RAISE EXCEPTION lx_error.
ENDTRY.
```

   Texts of findings are messages of the consumer's own message class (`ZCL_CA_OPS_UTIL=>MESSAGE_TEXT`),
   never literals. SLA days of the consumer's exceptions: parameters `SLA_DAYS_<area>_<B|E|W>` in area
   `CA_OPS` (the consumer delivers their definitions), fallback `SLA_DAYS_DEFAULT`. A second run while one
   is running: `ZIF_CA_OPS_LOCK` (`ZCL_CA_OPS_FACTORY=>GET_LOCK( )`) and `ZCL_CA_OPS_RUN_GUARD=>REFUSE`.

4. **Raise alerts.** No code: rows in `ZCA_OPS_ALRULE` (area of the consumer or `*`, severity floor, PCRE
   patterns on rule / check / groups matched to the complete value, run RAG, abort, channel EMAIL or
   APPLOG, destination, digest, throttle, quiet hours, escalation) in the app `ZUI_CA_OPS_CFG`; `DISPATCH`
   above applies them. A prepared report goes out by e-mail with

```abap
zcl_ca_ops_factory=>get_alert( )->send( iv_route = 'ZXX_DAILY' iv_subject = lv_subject iv_html = lv_html ).
" recipients: parameter ALERT_ZPE_DAILY in area CA_OPS (SO23 lists), fallback ALERT_DEFAULT
```

   **Every alert e-mail is a template** (SAP e-mail templates, `docs/ALERT_TEMPLATES.md`): the rule's
   `TEMPLATE_ID`, else the section's, else the channel's, else `ALERT_TEMPLATE_DEFAULT`
   (`ZCA_OPS_ALERT_DEFAULT`); the template has plain-text placeholders for the standard context keys
   (`{{SUBJECT}}`, `{{AREA}}`, `{{RULE_ID}}`, `{{FINDINGS_TOTAL}}`, `{{DUE_DATE}}`, ...) and the markers
   `{{TABLE_MAIN}}` / `{{TABLE_SECTION}}` where the code puts its tables. When SAP e-mail templates cannot be
   used the built-in layout is sent and the alert log row says why. Amounts are shown only on rules with
   `SHOW_AMOUNTS` = X. Fill the business context of a finding where it is known at finding time:

```abap
ls_finding-business_date = ls_statement-stmt_date.        " blank = not known: the template never breaks
ls_finding-company_code  = ls_statement-bukrs.       " stored (BUKRS): read / change authorisation, alert routing
ls_finding-account       = lv_account_label.               " house bank / account ID or masked - never in full
ls_finding-item_count    = ls_file-record_count.
ls_finding-context       = lv_label_line.                " labelled lines, never amounts (DETAILS: only with SHOW_AMOUNTS)
```

5. **Add an alert section plug-in** (optional) - the consumer's own table in the alert message: a class
   implementing `ZIF_CA_OPS_ALERT_SECTION`, named in the parameter `ALERT_SECTION_CLASS` (area `CA_OPS`):

```abap
CLASS zcl_xx_alert_section DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_alert_section.
ENDCLASS.

CLASS zcl_xx_alert_section IMPLEMENTATION.
  METHOD zif_ca_ops_alert_section~owns.        " the finding is shown in this section
    rv_owns = xsdbool( is_finding-check_code = gc_check_ack_missing ).
  ENDMETHOD.
  METHOD zif_ca_ops_alert_section~subject.     " blank = the general subject
  ENDMETHOD.
  METHOD zif_ca_ops_alert_section~html.        " escaped by the section (ZCL_CA_OPS_UTIL=>HTML_ESCAPE)
    rv_html = |<table>...</table>|.
  ENDMETHOD.
  METHOD zif_ca_ops_alert_section~text.
  ENDMETHOD.
  METHOD zif_ca_ops_alert_section~template_id.  " optional: template of messages with owned findings
    rv_template_id = 'ZXX_ALERT_ACK'.             " its table goes where the template has {{TABLE_SECTION}}
  ENDMETHOD.
ENDCLASS.
```

6. **Register a purge target** for the consumer's own tables: a class implementing
   `ZIF_CA_OPS_PURGE_TARGET` (count / delete one package of a target with the consumer's keep rules, no
   commit) and a row of `ZCA_OPS_PURGE` in `ZUI_CA_OPS_CFG` (target, class, retention parameter area +
   name; class and parameter checked on save). `ZCA_OPS_RETENTION` purges RUN, ALERT_LOG and every
   registered target, never below 30 days, one commit per package, test mode counts only.

```abap
CLASS zcl_xx_purge_target DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_purge_target.
ENDCLASS.

CLASS zcl_xx_purge_target IMPLEMENTATION.
  METHOD zif_ca_ops_purge_target~count_purgeable.
    SELECT COUNT(*) FROM zxx_event WHERE created_at < @iv_cutoff INTO @rv_count.
  ENDMETHOD.
  METHOD zif_ca_ops_purge_target~delete_package.
    SELECT event_id FROM zxx_event WHERE created_at < @iv_cutoff
      ORDER BY event_id INTO TABLE @DATA(lt_keys) UP TO @iv_max ROWS.
    DELETE zxx_event FROM TABLE @( CORRESPONDING #( lt_keys ) ).
    rv_count = sy-dbcnt.                       " no commit: the purge commits per package
  ENDMETHOD.
ENDCLASS.
" ZCA_OPS_PURGE: TARGET = ZXX_EVENT, CLASS_NAME = ZCL_XX_PURGE_TARGET,
"                PARAM_AREA = CA_OPS, PARAM_NAME = RETENTION_DAYS_ZPE_EVENT (definition delivered by the consumer)
```

7a. **Register a business process** (2026-11-10): instead of writing steps 3-6 for every monitored flow, register
   the process and its checks - no-code aggregate rows (`ZCA_OPS_AGG`) or one class implementing
   `ZIF_CA_OPS_CHECK` - and schedule `ZCA_OPS_CHECK_RUN` for its area and schedule group: the runner does the run,
   lock, store, auto-resolve and alert routing; the process shows up in the exceptions app, the daily review
   (control rows with `GROUP2` = check ID), the area dashboard with freshness, the purge and the morning
   completeness check. Scaffold `../tools/abaptools/new_process.py`, guide `docs/ADDING_A_BUSINESS_PROCESS.md`.

```abap
CLASS zcl_xx_c_refund DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_check.
ENDCLASS.

CLASS zcl_xx_c_refund IMPLEMENTATION.
  METHOD zif_ca_ops_check~run.             " GROUP1 / GROUP2 are stamped by the runner
    rs_result-findings = NEW zcl_xx_refund_dao( )->rejected_without_refund( is_context-today ).
    rs_result-item_count = lines( rs_result-findings ).
  ENDMETHOD.
ENDCLASS.
" ZCA_OPS_CHECK: AREA = ZXX_OPS, CHECK_ID = XX_REFUND, PROCESS_ID = PAY_LIFE, CLASS_NAME = ZCL_XX_C_REFUND,
"                SCHED_GROUP = DAILY, BUKRS_AWARE = X, ACTIVE = X
```

7. **Register daily controls** (optional): rows of `ZCA_OPS_CONTROL` / `ZCA_OPS_CTLT` / `ZCA_OPS_CTLCHK` in
   `ZUI_CA_OPS_CFG` name the consumer's checks (area of the findings, `RULE_ID` / `CHECK_CODE` / `GROUP2` =
   exact value); the framework derives each control's status per business date from their findings, the
   reviewers sign off in `ZUI_CA_OPS_REV`, and the consumer's own cards select from `ZR_CA_OpsCtlReview`
   (`docs/CONTROL_REVIEW.md`). Nothing to code.
8. **Errors.** Derive the consumer's exception from `ZCX_CA_OPS_ERROR` and redefine `CLASSIFY` for its
   message class (TRANSIENT / CONFIG); `ZCL_CA_OPS_UTIL=>ERROR_CLASS` walks the whole chain.
9. **Tests.** `ZCL_CA_OPS_INJECTOR` writes doubles into `ZCL_CA_OPS_FACTORY` (`INJECT_STORE`, `INJECT_ALERT`,
   `INJECT_AUTH`, `INJECT_CLOCK`, ..., `RESET` in `teardown`); `NEW zcl_ca_ops_param_seed( )` is an in-memory
   parameter store over the real ZCA_PARAM logic (areas `ZT_OPS_A` / `_B` for tests). The demo's test
   include shows all of it without a database.

## Documentation

| Document | Content |
|---|---|
| `docs/INSTALL.md` | installing at a new customer: checklist (name clashes, reuse rights), pull order, SU21, roles, SLG0, SO23, parameters, purge job, first area, verification with the demo |
| `docs/auth_zca_ops.md` | authorisation object ZCA_OPS: fields, activities, roles, DCLs |
| `docs/PARAMETERS.md` | the framework's parameters (area CA_OPS) and the names consumers complete |
| `docs/ALERT_TEMPLATES.md` | alert e-mail templates: how a mail is built, context keys, configuration, fallback, delivery, VERIFY items |
| `templates/` | the framework's e-mail templates as documented sources (generic template `ZCA_OPS_ALERT_DEFAULT`) |
| `docs/ADDING_A_BUSINESS_PROCESS.md` | adding a business process end to end (Fiori to backend): registry, no-code aggregate or check class, control, alert rule, dashboard, freshness, purge, authorisation, completeness checks; worked example |
| `docs/JOB_MONITORING.md` | SAP job monitor: failures of every job of the client, parent / child links and their evidence quality, granularity chain kept as evidence, window and caps, board, performance, purge, adoption |
| `docs/OPERATIONS_FEATURES.md` | operations response features (2026-11-11): runbook links, planned downtime, escalation until acknowledged, alert correlation, response-time metrics, shift handover - configuration, rules, decisions, objects |
| `docs/CONTROL_REVIEW.md` | control register and daily control review: which findings belong to a control, derived status, sign-off, awaiting / overdue review, review app |
| `docs/VERIFY.md` | what offline checks cannot prove |
| `CHANGELOG.md` | changes, releases |

## Repository layout and quality gates

| Path | Purpose |
|---|---|
| `src/`, `src/ui/`, `src/demo/` | abapGit objects (`ZCA_OPS`, `ZCA_OPS_UI`, optional demo `ZCA_OPS_DEMO`) |
| `ddic/`, `ddic/ui/` | table DDL sources (`ddic/ui`: draft tables, generated) and `dictionary.json` |
| `config/` | repository settings, message class `zca_ops_messages.md`, authorisation object, parameter seeds, `customer_terms.txt` (words and object prefixes of consumers) and `customer_terms_allowed.txt` (the few lines that may name one, with the reason); `config/demo/` seed rows of the demo |
| `docs/text_elements/` | text pools of programs and classes |
| `tools/abapgit_serialize.py` | writes all abapGit XML from `ddic/`, `config/`, the sources and the text elements |
| `tools/param_definitions.py` | the framework's profile of the parameter seed generator (seed class `ZCL_CA_OPS_PARAM_SEED`) |
| `tools/rap_generate.py` | the framework's profile of the RAP generator (app `ZUI_CA_OPS_CFG`) |
| `tools/checks.py` | house checks incl. messages, test paths, layering (no consumer reference), customer wording, packaging, completeness of registered processes (`process_onboarding`) |

The files in `tools/` are thin wrappers: the engines are the shared tools of the repository
(`../tools/abaptools`, tests in `../tools/tests`), one implementation for the parameter framework, this
framework and every consumer.
| `ci/abaplint.yml` | CI workflow (to be wired into `.github/workflows` of `jaideep247/bai`) |

The configuration app `ZUI_CA_OPS_CFG` is generated by `tools/rap_generate.py` - never edit the
generated files. Run locally from this folder:

```sh
npx @abaplint/cli@2.120.92 abaplint.json        # syntax and house rules (v758), ZCA_PARAM as dependency
python3 tools/abapgit_serialize.py --check      # abapGit metadata up to date
python3 tools/param_definitions.py --check      # parameter definitions and seed class
python3 tools/rap_generate.py --check           # configuration app generated from ddic/
python3 tools/checks.py                         # house checks
python3 -m unittest discover -s tools/tests     # tool tests
```

A clean lint proves syntax and typing against the SAP stubs of `abaplint/deps` only - not activation,
DDIC existence or ABAP Unit results (`docs/VERIFY.md`). Nothing of this framework has run in an SAP
system yet.

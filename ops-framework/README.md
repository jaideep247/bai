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
| Store | `ZIF_CA_OPS_STORE` / `ZCL_CA_OPS_STORE`, tables `ZCA_OPS_RUN`, `ZCA_OPS_FINDING`, `ZCA_OPS_EXC_HIST` |
| Exceptions | `ZIF_CA_OPS_EXC_DAO` / `ZCL_CA_OPS_EXC_DAO`, `ZCL_CA_OPS_EXC_POLICY`, `ZIF_CA_OPS_EXC_TYPES`; app `ZUI_CA_OPS_EXC` (RAP BO `ZR_CA_OpsException`, sub-package `ZCA_OPS_UI`) |
| Alerting | `ZIF_CA_OPS_ALERT` / `ZCL_CA_OPS_ALERT_ROUTER`, `ZCL_CA_OPS_ALERT_POLICY`, `ZIF_CA_OPS_ALERT_DAO` / `ZCL_CA_OPS_ALERT_DAO`, channels `ZIF_CA_OPS_ALERT_CHANNEL` (`ZCL_CA_OPS_CHN_EMAIL`, `ZCL_CA_OPS_CHN_APPLOG`), consumer sections `ZIF_CA_OPS_ALERT_SECTION`; tables `ZCA_OPS_ALRULE`, `ZCA_OPS_ALCHN`, `ZCA_OPS_ALLOG` |
| Run control | `ZIF_CA_OPS_LOCK` / `ZCL_CA_OPS_LOCK` (lock argument `ZCA_OPS_LOCK`), `ZCL_CA_OPS_RUN_GUARD` (refuse / abort) |
| Configuration apps | gate `ZCL_CA_OPS_CFG_GATE` (+ `_CLIENT`, `_TRANSPORT`, `_AUTH`, `_POLICY`, `_FACTORY`, `_INJECTOR`, `ZIF_CA_OPS_CFG_*`), field checks `ZCL_CA_OPS_CFG_CHECKS`; app `ZUI_CA_OPS_CFG` (alert rules, channels, purge targets; generated) |
| Retention purge | `ZCL_CA_OPS_PURGE`, `ZIF_CA_OPS_PURGE_DAO` / `ZCL_CA_OPS_PURGE_DAO`, targets `ZIF_CA_OPS_PURGE_TARGET`, registry `ZCA_OPS_PURGE`, report `ZCA_OPS_RETENTION` |
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
  `ZUI_CA_OPS_CFG_O4` (OData V4 - UI), create the SLG0 object `ZCA_OPS` / sub-object `ALERT` when
  a rule uses the APPLOG channel, run ABAP Unit and ATC, run the demo report `ZCA_OPS_DEMO`, work through
  `docs/VERIFY.md`.

| Demo (optional, not for production) | Objects |
|---|---|
| Sub-package `ZCA_OPS_DEMO` | report `ZCA_OPS_DEMO`, `ZCL_CA_OPS_DEMO` (the consumer: run, findings, alerts), `ZIF_CA_OPS_DEMO_DAO` / `ZCL_CA_OPS_DEMO_DAO` (job counts of `TBTCO`, read only), `ZIF_CA_OPS_DEMO_TYPES`; messages 900-903 of `ZCA_OPS`; seed rows `config/demo/` (area `CA_DEMO`, channel APPLOG, rule `DEMO_LOG`) |

## How a consumer uses it

A consumer is any team's check, monitor or report; it references only `ZCA_*` objects and SAP standard
(the demo `src/demo/zcl_ca_ops_demo.clas.abap` is a complete example in 200 lines, with its unit test).

1. **Register an area.** The area is a parameter area of ZCA_PARAM (one area register,
   `ZCA_PARAM_AREA`, at most 16 characters, e.g. `ZPE_OPS`) - enter it in the parameter app. Every run,
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
DATA(lv_days) = lo_params->get_param( iv_name = 'ZPE_LOOKBACK_DAYS' iv_area = gc_area iv_default = `7` ).
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
zcl_ca_ops_factory=>get_alert( )->send( iv_route = 'ZPE_DAILY' iv_subject = lv_subject iv_html = lv_html ).
" recipients: parameter ALERT_ZPE_DAILY in area CA_OPS (SO23 lists), fallback ALERT_DEFAULT
```

5. **Add an alert section plug-in** (optional) - the consumer's own table in the alert message: a class
   implementing `ZIF_CA_OPS_ALERT_SECTION`, named in the parameter `ALERT_SECTION_CLASS` (area `CA_OPS`):

```abap
CLASS zcl_pe_alert_section DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_alert_section.
ENDCLASS.

CLASS zcl_pe_alert_section IMPLEMENTATION.
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
ENDCLASS.
```

6. **Register a purge target** for the consumer's own tables: a class implementing
   `ZIF_CA_OPS_PURGE_TARGET` (count / delete one package of a target with the consumer's keep rules, no
   commit) and a row of `ZCA_OPS_PURGE` in `ZUI_CA_OPS_CFG` (target, class, retention parameter area +
   name; class and parameter checked on save). `ZCA_OPS_RETENTION` purges RUN, ALERT_LOG and every
   registered target, never below 30 days, one commit per package, test mode counts only.

```abap
CLASS zcl_pe_purge_target DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_purge_target.
ENDCLASS.

CLASS zcl_pe_purge_target IMPLEMENTATION.
  METHOD zif_ca_ops_purge_target~count_purgeable.
    SELECT COUNT(*) FROM zpe_event WHERE created_at < @iv_cutoff INTO @rv_count.
  ENDMETHOD.
  METHOD zif_ca_ops_purge_target~delete_package.
    SELECT event_id FROM zpe_event WHERE created_at < @iv_cutoff
      ORDER BY event_id INTO TABLE @DATA(lt_keys) UP TO @iv_max ROWS.
    DELETE zpe_event FROM TABLE @( CORRESPONDING #( lt_keys ) ).
    rv_count = sy-dbcnt.                       " no commit: the purge commits per package
  ENDMETHOD.
ENDCLASS.
" ZCA_OPS_PURGE: TARGET = ZPE_EVENT, CLASS_NAME = ZCL_PE_PURGE_TARGET,
"                PARAM_AREA = CA_OPS, PARAM_NAME = RETENTION_DAYS_ZPE_EVENT (definition delivered by the consumer)
```

7. **Errors.** Derive the consumer's exception from `ZCX_CA_OPS_ERROR` and redefine `CLASSIFY` for its
   message class (TRANSIENT / CONFIG); `ZCL_CA_OPS_UTIL=>ERROR_CLASS` walks the whole chain.
8. **Tests.** `ZCL_CA_OPS_INJECTOR` writes doubles into `ZCL_CA_OPS_FACTORY` (`INJECT_STORE`, `INJECT_ALERT`,
   `INJECT_AUTH`, `INJECT_CLOCK`, ..., `RESET` in `teardown`); `NEW zcl_ca_ops_param_seed( )` is an in-memory
   parameter store over the real ZCA_PARAM logic (areas `ZT_OPS_A` / `_B` for tests). The demo's test
   include shows all of it without a database.

## Documentation

| Document | Content |
|---|---|
| `docs/INSTALL.md` | installing at a new customer: checklist (name clashes, reuse rights), pull order, SU21, roles, SLG0, SO23, parameters, purge job, first area, verification with the demo |
| `docs/auth_zca_ops.md` | authorisation object ZCA_OPS: fields, activities, roles, DCLs |
| `docs/PARAMETERS.md` | the framework's parameters (area CA_OPS) and the names consumers complete |
| `docs/VERIFY.md` | what offline checks cannot prove |
| `CHANGELOG.md` | changes, releases |

## Repository layout and quality gates

| Path | Purpose |
|---|---|
| `src/`, `src/ui/`, `src/demo/` | abapGit objects (`ZCA_OPS`, `ZCA_OPS_UI`, optional demo `ZCA_OPS_DEMO`) |
| `ddic/`, `ddic/ui/` | table DDL sources (`ddic/ui`: draft tables, generated) and `dictionary.json` |
| `config/` | repository settings, message class `zca_ops_messages.md`, authorisation object, parameter seeds, `customer_terms.txt`; `config/demo/` seed rows of the demo |
| `docs/text_elements/` | text pools of programs and classes |
| `tools/abapgit_serialize.py` | writes all abapGit XML from `ddic/`, `config/`, the sources and the text elements |
| `tools/param_definitions.py` | the framework's profile of the parameter seed generator (seed class `ZCL_CA_OPS_PARAM_SEED`) |
| `tools/rap_generate.py` | the framework's profile of the RAP generator (app `ZUI_CA_OPS_CFG`) |
| `tools/checks.py` | house checks incl. messages, test paths, layering (no consumer reference), customer wording, packaging |

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

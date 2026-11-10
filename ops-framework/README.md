# ZCA_OPS - cross-application operations framework

A reusable framework for SAP operations checks on S/4HANA 2023, SAP_BASIS 7.58, classic ABAP. A
**consumer** (a team's monitoring, validation or health check) runs **checks** in its **area**,
writes their **findings** into one auditable store, and the framework turns findings of severity
B / E / W into owned **exceptions** with an SLA due date, raises **alerts** by configurable rules,
guards runs with a lock and an abort boundary, gates its configuration apps by client role and
transport, and purges its history by retention.

The source lives in the repository `jaideep247/bai`, folder `ops-framework/` (this folder is the
framework root; every path below is relative to it). It was extracted on 2026-11-10 from its first
consumer, the payment engine operations suite (`ops-suite/`), which now consumes it.

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

Package `ZCA_OPS` (sub-package `ZCA_OPS_UI` from folder `src/ui`), folder logic PREFIX, starting
folder `/src/` of this folder (`/ops-framework/src/` of the repository, see `.abapgit.xml`).

- **Offline ZIP**: in a clone of `jaideep247/bai` run
  `git archive HEAD:ops-framework --format=zip -o zca_ops.zip`, then in abapGit
  *New Offline* -> package `ZCA_OPS` -> *Import ZIP* -> *Pull*.
- After the pull: register area `CA_OPS` and the definitions of `config/param_definitions.csv` in the
  ZCA_PARAM app (`ZUI_CA_PARAM_O4`), create the service bindings `ZUI_CA_OPS_EXC_O4` and
  `ZUI_CA_OPS_CFG_O4` (OData V4 - UI), create the SLG0 object `ZCA_OPS` / sub-object `ALERT` when
  a rule uses the APPLOG channel, run ABAP Unit and ATC, work through `docs/VERIFY.md`.

## How a consumer uses it

1. **Register an area.** The area is a parameter area of ZCA_PARAM (one area register,
   `ZCA_PARAM_AREA`, e.g. `ZPE_OPS`). Every run, finding, alert rule, lock and authorisation of the
   consumer names it; `start_run` refuses an unknown or inactive area (message 043). Give users
   object `ZCA_OPS` with `ZCA_PARAR` = the area (`docs/auth_zca_ops.md`).
2. **Read parameters** through `ZCL_CA_OPS_FACTORY=>GET_PARAMS( )` (or the consumer's factory,
   which adds its name prefixes with `ADD_PREFIXES`); pass `iv_area` or let the longest prefix decide.
3. **Write findings.**

```abap
DATA(lo_store) = zcl_ca_ops_factory=>get_store( ).
DATA(ls_run) = lo_store->start_run( iv_area = 'ZPE_OPS' iv_variant = 'DAILY' ).
lo_store->commit( ).                          " durable before notified
TRY.
    lo_store->save_findings( EXPORTING it_findings = lt_findings CHANGING cs_run = ls_run ).
    lo_store->finish_run( ls_run ).
    lo_store->commit( ).
    zcl_ca_ops_factory=>get_alert( )->dispatch( is_run = ls_run it_findings = lt_findings ).
  CATCH zcx_ca_ops_error INTO DATA(lx_error).  " covers the consumer's subclass too
    zcl_ca_ops_run_guard=>abort( EXPORTING ix_error = lx_error CHANGING cs_run = ls_run ).
    RAISE EXCEPTION lx_error.
ENDTRY.
```

   SLA days of the consumer's exceptions: parameters `SLA_DAYS_<area>_<B|E|W>` in area `CA_OPS`
   (the consumer delivers their definitions), fallback `SLA_DAYS_DEFAULT`.
4. **Raise alerts.** Rows in `ZCA_OPS_ALRULE` (area of the consumer or `*`, severity floor, PCRE
   patterns on rule / check / groups, run RAG, abort, channel, destination, digest, throttle, quiet
   hours, escalation) in app `ZUI_CA_OPS_CFG`; a report goes out with `GET_ALERT( )->SEND( iv_route )`
   (recipients `ALERT_<route>` in `CA_OPS`). A consumer's own table in the message: a class of
   `ZIF_CA_OPS_ALERT_SECTION` named in parameter `ALERT_SECTION_CLASS`.
5. **Register a purge target.** A class of `ZIF_CA_OPS_PURGE_TARGET` (count / delete one package of a
   target with the consumer's keep rules, no commit) and a row of `ZCA_OPS_PURGE` (target, class,
   retention parameter area + name; checked on save). `ZCA_OPS_RETENTION` purges RUN, ALERT_LOG and
   every registered target, never below 30 days, one commit per package, test mode counts only.
6. **Errors.** Derive the consumer's exception from `ZCX_CA_OPS_ERROR` and redefine `CLASSIFY` for its
   message class (TRANSIENT / CONFIG); `ZCL_CA_OPS_UTIL=>ERROR_CLASS` walks the whole chain.
7. **Tests.** `ZCL_CA_OPS_INJECTOR` writes doubles into `ZCL_CA_OPS_FACTORY`; `NEW zcl_ca_ops_param_seed( )`
   is an in-memory parameter store over the real ZCA_PARAM logic (areas `ZT_OPS_A` / `_B` for tests).

## Documentation

| Document | Content |
|---|---|
| `docs/auth_zca_ops.md` | authorisation object ZCA_OPS: fields, activities, roles, DCLs |
| `docs/PARAMETERS.md` | the framework's parameters (area CA_OPS) and the names consumers complete |
| `docs/VERIFY.md` | what offline checks cannot prove |
| `CHANGELOG.md` | changes, releases |

## Repository layout and quality gates

| Path | Purpose |
|---|---|
| `src/`, `src/ui/` | abapGit objects (`ZCA_OPS`, `ZCA_OPS_UI`) |
| `ddic/`, `ddic/ui/` | table DDL sources (`ddic/ui`: draft tables, generated) and `dictionary.json` |
| `config/` | repository settings, message class `zca_ops_messages.md`, authorisation object, parameter seeds, `customer_terms.txt` |
| `docs/text_elements/` | text pools of programs and classes |
| `tools/abapgit_serialize.py` | writes all abapGit XML from `ddic/`, `config/`, the sources and the text elements |
| `tools/param_definitions.py` | parameter seed generator (configurable; the suite's profile is `ops-suite/tools/param_definitions.py`) |
| `tools/checks.py` | house checks incl. messages, test paths, layering (no consumer reference) and customer wording |
| `ci/abaplint.yml` | CI workflow (to be wired into `.github/workflows` of `jaideep247/bai`) |

The configuration app `ZUI_CA_OPS_CFG` is generated by `ops-suite/tools/rap_generate.py` (app
`framework` of its spec) - never edit the generated files. Run locally from this folder:

```sh
npx @abaplint/cli@2.120.92 abaplint.json        # syntax and house rules (v758), ZCA_PARAM as dependency
python3 tools/abapgit_serialize.py --check      # abapGit metadata up to date
python3 tools/param_definitions.py --check      # parameter definitions and seed class
python3 tools/checks.py                         # house checks
python3 -m unittest discover -s tools/tests     # tool tests
```

A clean lint proves syntax and typing against the SAP stubs of `abaplint/deps` only - not activation,
DDIC existence or ABAP Unit results (`docs/VERIFY.md`). Nothing of this framework has run in an SAP
system yet.

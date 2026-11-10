# Installing ZCA_OPS at a new customer

> **First principle:** the framework is installed once per landscape, before any consumer, on top of the parameter framework; everything a customer decides (areas, people, alert routes, retention) is configuration entered after the pull, never code.
> **Analogy:** fitting a building with a fire panel — the panel and its wiring come first (ZCA_PARAM, ZCA_OPS), then each tenant's zones and sirens are configured (areas, alert rules), and a test alarm proves it works (the demo report).

Every path below is relative to the framework folder (`ops-framework/`). Nothing of the framework has
run in an SAP system yet: the first installation is also the first activation (see `docs/VERIFY.md`).

## 0. Before installing at a new customer — checklist

| # | Check | How |
|---|---|---|
| C1 | **Reuse rights confirmed.** Confirm with the owner of this code and with the customer that the framework may be installed and reused there (contract, ownership of the code, licence of the delivery). | Written confirmation in the project file |
| C2 | **Release.** S/4HANA 2023 or later, SAP_BASIS 7.58 (classic ABAP, RAP with draft, OData V4). | System → Status |
| C3 | **No name clash on the prefix `ZCA`.** None of the object names below exists in the customer system (TADIR, SE80, SU21, SE91). The prefix is not a registered namespace: a customer object with the same name stops the pull or, worse, is overwritten. | SE16 on `TADIR` with `OBJ_NAME` patterns below (field `OBJECT` any), SU21, SE91, SLG0 |
| C4 | **abapGit** (standalone report or developer version) is available in the development system, and ADT for the service bindings. | SE38 / ADT |
| C5 | **ZCA_PARAM release 1.1.0 or later** is installed or installed first (step 1). `start_run` refuses every run on an older release (message 044). | `ZIF_CA_PARAM_TYPES=>GC_VERSION` |
| C6 | **Customer wording.** The framework carries no customer, bank or system names (check `customer_terms` of `tools/checks.py`); extend `config/customer_terms.txt` with the new customer's names before the first change. | `python3 tools/checks.py` |

Names to look up in `TADIR` before the first pull (C3) - patterns, `*` = any characters:

| Kind | Operations framework (`ZCA_OPS`) | Parameter framework (`ZCA_PARAM`) |
|---|---|---|
| Packages (DEVC) | `ZCA_OPS`, `ZCA_OPS_UI`, `ZCA_OPS_DEMO` | `ZCA_PARAM`, `ZCA_PARAM_UI` |
| Classes, interfaces | `ZCL_CA_OPS*`, `ZIF_CA_OPS*`, `ZCX_CA_OPS*`, `ZBP_R_CA_OPS*` | `ZCL_CA_PARAM*`, `ZIF_CA_PARAM*`, `ZCX_CA_PARAM*`, `ZBP_R_CA_PARAM*` |
| Programs | `ZCA_OPS_RETENTION`, `ZCA_OPS_DEMO` | - |
| Tables | `ZCA_OPS_*` (8), draft tables `ZCA_D_ALCHN`, `ZCA_D_ALRULE`, `ZCA_D_OPSCFG`, `ZCA_D_PURGE` | `ZCA_PARAM_*` (3), draft tables `ZCA_D_PARAREA`, `ZCA_D_PARDEF`, `ZCA_D_PARVAL` |
| Domains, data elements | - | `ZCA_PARAM_*` |
| CDS, behaviour, service, access control | `ZR_CA_*`, `ZC_CA_*`, `ZI_CA_*`, `ZA_CA_*` (e.g. `ZR_CA_ALERTRULE`, `ZA_CA_EXCWAIVER`), `ZUI_CA_OPS_CFG`, `ZUI_CA_OPS_EXC` (+ bindings `*_O4`) | `ZR_CA_PARAM*`, `ZC_CA_PARAM*`, `ZI_CA_PARAM*`, `ZUI_CA_PARAM` (+ binding `*_O4`) |
| Authorisation (SU21 / SU20) | object `ZCA_OPS` | object class `ZCA`, object `ZCA_PARAM`, field `ZCA_PARAR` |
| Message classes (SE91) | `ZCA_OPS` | `ZCA_PARAM` |
| Application log (SLG0) | object `ZCA_OPS`, sub-object `ALERT` | - |
| Roles (PFCG, proposal) | `Z_CA_OPS_*` | `Z_CA_PARAM_*` |

The complete list of each component is its `src/` folder (one file per object); a clash on any single
name is resolved before the pull (rename on the customer side or a decision to rename the framework -
the latter is a change of the framework, not of the installation).

## 1. abapGit pull order

**ZCA_PARAM 1.1.0 -> ZCA_OPS -> consumer(s).** Each component is its own abapGit repository (folder logic
PREFIX, starting folder `/src/`); none needs a consumer.

1. Parameter framework: package `ZCA_PARAM` from `param-framework/` (offline ZIP:
   `git archive HEAD:param-framework --format=zip -o zca_param.zip`, abapGit *New Offline* -> *Import ZIP*
   -> *Pull*). Follow `param-framework/README.md` (service binding `ZUI_CA_PARAM_O4`, roles).
2. Operations framework: package `ZCA_OPS` from this folder
   (`git archive HEAD:ops-framework --format=zip -o zca_ops.zip`). Sub-packages are created from the folders:
   `ZCA_OPS_UI` (`src/ui`, the apps) and **`ZCA_OPS_DEMO` (`src/demo`, optional)**. To leave the demo out
   (production), remove it from the ZIP before the import: `zip -d zca_ops.zip 'src/demo/*'` - nothing else
   refers to it. Activate in the order abapGit proposes; on errors activate `ZIF_CA_OPS_TYPES` and the
   tables first, then the rest (V01).
3. Consumers, each from its own repository, after the framework.

After the pull create in ADT the service bindings `ZUI_CA_OPS_EXC_O4` and `ZUI_CA_OPS_CFG_O4`
(OData V4 - UI) on the service definitions of the same name, and publish them.

## 2. Authorisation

**SU21** - object `ZCA_OPS` in object class `ZCA` (the class and the field `ZCA_PARAR` come with ZCA_PARAM),
fields `ZCA_PARAR`, `ACTVT`, `BUKRS`, activities 01 02 03 06 16 85. abapGit creates it from
`src/zca_ops.suso.xml`; check it in SU21 (V03). Definition sheet: `docs/auth_zca_ops.md`.

**Roles (PFCG)** - sample matrix; one role per job, areas as the organisational split:

| Role | Who | ZCA_PARAR | ACTVT | BUKRS |
|---|---|---|---|---|
| `Z_CA_OPS_DISPLAY` | anyone who reads runs, exceptions, alerts | `*` or the reader's areas | 03 | `*` |
| `Z_CA_OPS_OPERATOR` | works the exceptions of an area (assign, resolve, request a waiver) | the area | 02, 03 | `*` |
| `Z_CA_OPS_APPROVER` | second person: approves waivers (never the requester) | the area | 03, 85 | `*` |
| `Z_CA_OPS_CONFIG` | maintains alert rules, channels, purge targets (DV1, on a customizing request) | `CA_OPS` and the consumer areas whose rules it keeps | 01, 02, 03, 06 | `*` |
| `Z_CA_OPS_BATCH` | job user of the retention purge and the consumers' jobs | `CA_OPS` + the consumer areas it runs | 16 | `*` |
| `Z_CA_OPS_DEMO` | installation check only (not in production) | `CA_DEMO` | 03, 16 | `*` |

Users who maintain parameters also need the parameter framework's object `ZCA_PARAM` for the area
(`CA_OPS`, the consumer areas) - see `param-framework/README.md`.

## 3. Application log and distribution lists

- **SLG0**: object `ZCA_OPS` with sub-object `ALERT` - the default destination of the APPLOG alert channel
  (`ZCL_CA_OPS_CHN_APPLOG`, destination `OBJECT/SUBOBJECT`). Needed only when a rule uses APPLOG (the demo
  does). Keep SLG1 minimal: a rule on APPLOG should be severity E or higher (the demo rule is W), digest on,
  a small `MAX_ITEMS`.
- **SO23**: shared distribution lists for the EMAIL channel - one list per audience (e.g. operations,
  support, escalation). Alert rules and the parameter `ALERT_DEFAULT` name lists, never mail addresses;
  the configuration app refuses a name that is not a shared list (message 419). SAPconnect (SCOT) must
  deliver mail from the system.

## 4. Parameters (area CA_OPS)

In the parameter app (`ZUI_CA_PARAM_O4`), in the customizing client on a customizing request:

1. Area **`CA_OPS`** (`config/param_areas.csv`, 1 row).
2. The **7 definitions** of `config/param_definitions.csv` (`ALERT_DEFAULT`, `ALERT_ESCALATION_WINDOW_H`,
   `ALERT_SECTION_CLASS`, `PURGE_PACKAGE_SIZE`, `RETENTION_DAYS_ALERT_LOG`, `RETENTION_DAYS_RUN`,
   `SLA_DAYS_DEFAULT`) exactly as listed - meaning and defaults in `docs/PARAMETERS.md`.
3. Value rows only where the default does not fit (e.g. `ALERT_DEFAULT` = the SO23 list of the support team).

Each consumer then delivers its own names in area `CA_OPS` (`ALERT_<route>`, `SLA_DAYS_<area>_<B|E|W>`,
retention parameters of its purge targets) from its own seed files.

## 5. Retention purge job

Schedule `ZCA_OPS_RETENTION` monthly (SM36 or the landscape's job scheduler) with a variant **test mode
off**, job user with `Z_CA_OPS_BATCH` (`ZCA_PARAR` = `CA_OPS`, ACTVT 16). Run it once in test mode first:
it lists RUN, ALERT_LOG and every active purge target of `ZCA_OPS_PURGE` with the rows it would delete
(never below 30 days, one commit per package). A purge target row whose class does not implement
`ZIF_CA_OPS_PURGE_TARGET` stops the run before anything is deleted (032).

## 6. First area of a consumer

1. Register the area in ZCA_PARAM (`ZCA_PARAM_AREA`, parameter app): one area per consumer or per
   functional split (e.g. `<TEAM>_<TOPIC>`, at most 16 characters). The area is the authorisation value
   (`ZCA_PARAR`), the alert rule area and the lock argument.
2. Give users the roles of section 2 with that area.
3. Enter the consumer's alert rules for the area in the configuration app `ZUI_CA_OPS_CFG` (or rely on
   rules with area `*`), and its SLA parameters `SLA_DAYS_<area>_<B|E|W>` if the default of 1 day does not fit.
4. Register its purge targets in `ZCA_OPS_PURGE` (configuration app) when it has own tables to purge.

How a consumer writes findings, raises alerts and plugs in: `README.md` (section *How a consumer uses it*).

## 7. Verify the installation (demo report)

The optional sub-package `ZCA_OPS_DEMO` is a complete, minimal consumer: report `ZCA_OPS_DEMO` starts a run
of area `CA_DEMO`, counts the background jobs of the client in the last 24 hours (`TBTCO`, read only) and
writes one information finding (jobs ended), an error (jobs cancelled - an open exception) and a warning
(released jobs not started 60 minutes after their planned start). Seed rows: `config/demo/`.

1. Area `CA_DEMO`: enter the row of `config/demo/param_areas_demo.csv` in the parameter app.
2. Alert channel `APPLOG` (if not maintained yet): row of `config/demo/alert_channels_demo.csv` in
   `ZUI_CA_OPS_CFG` (channels); SLG0 object `ZCA_OPS` / `ALERT` (section 3).
3. Alert rule `DEMO_LOG`: row of `config/demo/alert_rules_demo.csv` in `ZUI_CA_OPS_CFG` (alert rules): area
   `CA_DEMO`, severity W or worse, rule `DEMO`, check codes `DEMO_.*`, channel APPLOG, digest.
4. Role `Z_CA_OPS_DEMO` for the tester (ZCA_OPS, `CA_DEMO`, 03 and 16).
5. Run `ZCA_OPS_DEMO` in **test mode** (default): result message 903 and the findings in a list; nothing
   is written, no alert. Then run it with **test mode off and *Sample* on**: the run is stored, the error
   and the warning appear as open exceptions in the exceptions app (`ZUI_CA_OPS_EXC_O4`, area `CA_DEMO`),
   one application log entry is written (SLG1, object `ZCA_OPS`, sub-object `ALERT`) and one row per
   delivery in `ZCA_OPS_ALLOG`. Run it again without *Sample*: exceptions no longer raised are resolved.
6. Run the ABAP Unit tests of the packages (`ZCA_OPS`, `ZCA_OPS_UI`, `ZCA_OPS_DEMO`) and the ATC default variant.
7. Production: do not import `ZCA_OPS_DEMO`, or delete it after the check (it holds no data of its own;
   delete the `CA_DEMO` area, its rule and its runs with the retention purge or leave them in DV1 / QA1).

Record the results against `docs/VERIFY.md` in the release pack.

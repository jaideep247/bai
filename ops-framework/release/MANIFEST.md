# Release manifest 1.0.0 (2026-11-15)

> Generated from `release/manifest.json` by `tools/release_manifest.py` - do not edit; change the manifest
> and regenerate. Procedure, harness and evidence: `docs/RELEASE_AND_INSTALL.md`.

**Operations framework with parameter framework, Release 1 (FI-CA Cash Operations)**

## Supported releases

| Id | Product | Status | Software components | Proof |
|---|---|---|---|---|
| S4H_2023 | SAP S/4HANA 2023, on-premise or private edition (classic ABAP, RAP with draft, OData V4) | target | SAP_BASIS 758, S4CORE 108 (V201) | V200 |
| S4H_2025 | SAP S/4HANA 2025 with FI-CA (reference system A4H, client 100) | reference | SAP_BASIS recorded by the harness (connect stage) (V201) | V200 |

## Components

| Component | Folder | Version | Version constant | Requires |
|---|---|---|---|---|
| ZCA_PARAM | `param-framework` | 1.1.0 | `gc_version` of `src/zif_ca_param_types.intf.abap` | - |
| ZCA_OPS | `ops-framework` | 1.0.0 | `gc_version` of `src/zif_ca_ops_types.intf.abap` | ZCA_PARAM >= 1.1.0 |

## Prerequisites

- **ABAPGIT**: abapGit (standalone report or developer version) in the development system - install route of the components (offline ZIP per component)
- **ADT**: ABAP Development Tools for the service bindings, ABAP Unit, ATC and the install harness (tools/qualify)
- **SLG0** (CORE): Application log object ZCA_OPS with sub-object ALERT (alert channel APPLOG)
- **SMTG** (CORE): E-mail template ZCA_OPS_ALERT_DEFAULT created from templates/ (optional, built-in renderer otherwise)
- **SSF** (CORE): Licence only: SSF application, PSE (parameter LIC_SSF_PROFILE) and the vendor certificate (STRUST). Not needed to install or activate - LIC_ENFORCE is delivered W
- **SO23** (CORE): Distribution lists of the customer for the e-mail channel (configuration after the install, never delivered)
- **PFCG** (CORE): Roles of the customer built from docs/auth_zca_ops.md and the parameter framework's role proposal (authorisation objects ZCA_OPS, ZCA_PARAM)
- **SAP standard tables** the product reads: `ops-framework/config/ddic/standard_tables.txt`; FI-CA tables (`^(DFKK|FKK|DPAY|TFK)`): FI-CA dictionary objects (contract accounting tables) must exist for objects that read them; the pack's processes need FI-CA in use (V202).
- **Licensing**: Activation and installation never depend on a licence: every object activates and every test runs with no licence installed and LIC_ENFORCE = W (harness stage licensing, V208). A licence only switches modules at run time.

## Packs

| Pack | Name | Status | Requires | Objects (rule) | Licence modules | Source contracts |
|---|---|---|---|---|---|---|
| PARAM | Parameter framework | release, required | - | ZCA_PARAM: src, src/ui | - | - |
| CORE | Operations framework core | release, required | PARAM | ZCA_OPS: src, src/ui | CORE, CONTROL, ONBOARD, JOBS, RESPONSE, LINKS, PAYMODEL | CHECK_CLASS, JOB_RESOLVER, JOB_ENRICHER, ALERT_SECTION, ALERT_CHANNEL, PURGE_TARGET |
| FICA_CASH | FI-CA Cash Operations | release | CORE | ZCA_OPS: src/cash, names `Z(CL|IF)_CA_OPS_PF_(?!ADAPTER$|TYPES$)\w+`, names `ZCL_CA_OPS_CHK_PAYFILE`, names `ZCA_OPS_PF_RUN`, names `ZCA_OPS_PF(FILE|PAY|EVT|MST|SRC|DAY)`, names `Z[RCI]_CA_OPSP(F\w+|AYFILE)`, names `ZUI_CA_OPS_PAYFILE` | CATALOGUE_FICA, CASH_OPS, BREAKS, FLOW | FLOW_SOURCE |
| FSCD_STANDARD | Standard FS-CD (catalogue content) | later | FICA_CASH | ZCA_OPS: none (content pack) | CATALOGUE_FSCD, CATALOGUE_FSRI | - |
| DEMO | Demo consumer (sandbox only) | release, never in production | CORE | ZCA_OPS: src/demo | - | - |

Licence modules and plug-in contracts that no pack names belong to `CORE`.

## Catalogue, seed data, open items and fixtures per pack

### PARAM - Parameter framework

- Fixture (abap_unit): `param-framework/src` - ABAP Unit test classes of the parameter framework (HARMLESS, SHORT)

| Step | By | Activation |
|---|---|---|
| 1 | install | Import param-framework (abapGit offline ZIP or tools/qualify), activate; packages ZCA_PARAM, ZCA_PARAM_UI |
| 2 | install | Service binding ZUI_CA_PARAM_O4 (OData V4 - UI) on service definition ZUI_CA_PARAM, publish |
| 3 | basis | Roles from the parameter framework's role proposal (authorisation object ZCA_PARAM, field ZCA_PARAR) |

### CORE - Operations framework core

- Catalogue package `S4CORE` (`ops-framework/config/catalogue/s4core.json`); processes qualified in this release: every process of the package (none qualified in this release)
- Seed rows by key: area CA_S4CORE, layer S4CORE, package S4CORE, prefix S4_
- Seed files: `ops-framework/config/check_registry.csv`, `ops-framework/config/param_areas.csv`, `ops-framework/config/param_definitions.csv`, `ops-framework/config/licensing/alert_rules_license.csv`
- Fixture (abap_unit): `ops-framework/src` - ABAP Unit test classes of the framework (OSQL / CDS test doubles, HARMLESS, SHORT)
- Fixture (offline): `ops-framework/config/catalogue/examples/xx_layer.json` - Worked example of a customer layer (fictitious customer XX)
- Fixture (offline): `ops-framework/config/links/examples/xx_overlay.json` - Worked example of a customer overlay of the link registry

| Step | By | Activation |
|---|---|---|
| 1 | install | Import ops-framework without src/demo (abapGit offline ZIP or tools/qualify), activate; packages ZCA_OPS, ZCA_OPS_UI |
| 2 | install | Service bindings <service definition>_O4 (OData V4 - UI) on every service definition of src/ui, publish |
| 3 | basis | SLG0 object ZCA_OPS / ALERT; roles from docs/auth_zca_ops.md; optional SMTG template from templates/ |
| 4 | configuration | Parameter seed: run ZCL_CA_OPS_PARAM_SEED (area CA_OPS, definitions with defaults; LIC_ENFORCE stays W) |
| 5 | configuration | Customizing request: product rows of the seed files of this pack (catalogue S4CORE, link layer S4CORE, break buckets, check registry) |
| 6 | verify | Demo pack in a sandbox (optional) and the check runner in test mode for area CA_OPS (docs/INSTALL.md section 7) |

### FICA_CASH - FI-CA Cash Operations

- Catalogue package `FICA` (`ops-framework/config/catalogue/packages/fica.json`); processes qualified in this release: FICA_PAYRUN, FICA_PAY_LOTS, FICA_RETURNS, FICA_EBS_LOTS, FICA_CLEARING, FICA_REVERSAL, FICA_GL_TRANSFER
- Seed rows by key: area CA_FICA, layer FICA, package FICA, prefix FICA_
- Fixture (offline): `ops-framework/config/flows` - Account flow templates DISB / COLL (inactive) checked by tools/checks.py flow_config
- Fixture (offline): `ops-framework/config/breaks` - Break buckets and product rules checked by tools/checks.py break_rules

| Step | By | Activation |
|---|---|---|
| 1 | configuration | Customizing request: product rows of the seed files of this pack (catalogue package FICA, link layer FICA, break rules, account flow templates) - every monitoring row and flow template delivered inactive |
| 2 | configuration | Catalogue activation of the qualified processes of this pack from a date, with reason and approver (four-eyes) - effective-dated, reversible |
| 3 | configuration | Per process: area, owner, approved tables (security sign-off), checks, control, alert rule (docs/ADDING_A_BUSINESS_PROCESS.md) |
| 4 | verify | VERIFY items of the pack (catalogue V124-V129, links V116-V120, breaks V135-V138, flows V145-V149, cash checks V220-V237) and the cash fixtures config/cash/fixtures.json |

### FSCD_STANDARD - Standard FS-CD (catalogue content)

- Catalogue package `FSCD` (`ops-framework/config/catalogue/packages/fscd.json`); processes qualified in this release: every process of the package (none qualified in this release)
- Seed rows by key: area CA_FSCD, package FSCD, prefix FSCD_

| Step | By | Activation |
|---|---|---|
| 1 | configuration | Not part of Release 1: catalogue rows are delivered, every monitoring row inactive |

### DEMO - Demo consumer (sandbox only)

- Seed files: `ops-framework/config/demo/alert_channels_demo.csv`, `ops-framework/config/demo/alert_rules_demo.csv`, `ops-framework/config/demo/param_areas_demo.csv`
- Fixture (abap_unit): `ops-framework/src/demo` - ABAP Unit test classes of the demo consumer

| Step | By | Activation |
|---|---|---|
| 1 | verify | Sandbox only (tools/qualify --with-demo): report ZCA_OPS_DEMO in test mode; never imported into production |

## Import order

PARAM -> CORE -> FICA_CASH -> FSCD_STANDARD -> DEMO

Within a component the install harness follows the object order of `tools/qualify` (tables, interfaces, exception classes, CDS, access controls, metadata extensions, behaviour, services, classes, programs) and activates the component in one mass activation.

## Seed files

| File | Table | Key | Kind |
|---|---|---|---|
| `ops-framework/config/catalogue/seed/zca_ops_catpkg.csv` | ZCA_OPS_CATPKG | PKG_ID | package |
| `ops-framework/config/catalogue/seed/zca_ops_catprc.csv` | ZCA_OPS_CATPRC | PKG_ID | package |
| `ops-framework/config/catalogue/seed/zca_ops_catstp.csv` | ZCA_OPS_CATSTP | PROCESS_ID | prefix |
| `ops-framework/config/catalogue/seed/zca_ops_cattab.csv` | ZCA_OPS_CATTAB | PROCESS_ID | prefix |
| `ops-framework/config/catalogue/seed/zca_ops_catdep.csv` | ZCA_OPS_CATDEP | PROCESS_ID | prefix |
| `ops-framework/config/catalogue/seed/zca_ops_catact.csv` | ZCA_OPS_CATACT | PKG_ID | package |
| `ops-framework/config/catalogue/monitoring/zca_ops_agg.csv` | ZCA_OPS_AGG | AREA | area |
| `ops-framework/config/catalogue/monitoring/zca_ops_alrule.csv` | ZCA_OPS_ALRULE | AREA | area |
| `ops-framework/config/catalogue/monitoring/zca_ops_check.csv` | ZCA_OPS_CHECK | AREA | area |
| `ops-framework/config/catalogue/monitoring/zca_ops_control.csv` | ZCA_OPS_CONTROL | AREA | area |
| `ops-framework/config/catalogue/monitoring/zca_ops_ctlchk.csv` | ZCA_OPS_CTLCHK | AREA | area |
| `ops-framework/config/catalogue/monitoring/zca_ops_ctlt.csv` | ZCA_OPS_CTLT | CONTROL_ID | prefix |
| `ops-framework/config/catalogue/monitoring/zca_ops_proc.csv` | ZCA_OPS_PROC | AREA | area |
| `ops-framework/config/catalogue/monitoring/zca_ops_tabwl.csv` | ZCA_OPS_TABWL | AREA | area |
| `ops-framework/config/links/seed/zca_ops_lnklyr.csv` | ZCA_OPS_LNKLYR | LAYER_ID | layer |
| `ops-framework/config/links/seed/zca_ops_lnkobj.csv` | ZCA_OPS_LNKOBJ | LAYER_ID | layer |
| `ops-framework/config/links/seed/zca_ops_lnkfld.csv` | ZCA_OPS_LNKFLD | LAYER_ID | layer |
| `ops-framework/config/links/seed/zca_ops_link.csv` | ZCA_OPS_LINK | LAYER_ID | layer |
| `ops-framework/config/links/seed/zca_ops_lnkcnd.csv` | ZCA_OPS_LNKCND | LINK_ID | prefix |
| `ops-framework/config/links/seed/zca_ops_lnkact.csv` | ZCA_OPS_LNKACT | LAYER_ID | layer |
| `ops-framework/config/breaks/zca_ops_brkbkt.csv` | ZCA_OPS_BRKBKT | LAYER_ID | layer |
| `ops-framework/config/breaks/zca_ops_brkrul.csv` | ZCA_OPS_BRKRUL | LAYER_ID | layer |
| `ops-framework/config/breaks/zca_ops_brkcnd.csv` | ZCA_OPS_BRKCND | RULE_ID | prefix |
| `ops-framework/config/flows/zca_ops_flow.csv` | ZCA_OPS_FLOW | AREA | area |
| `ops-framework/config/flows/zca_ops_flwacc.csv` | ZCA_OPS_FLWACC | AREA | area |
| `ops-framework/config/flows/zca_ops_flwctl.csv` | ZCA_OPS_FLWCTL | AREA | area |
| `ops-framework/config/flows/zca_ops_flwrul.csv` | ZCA_OPS_FLWRUL | AREA | area |
| `ops-framework/config/flows/zca_ops_flwstg.csv` | ZCA_OPS_FLWSTG | AREA | area |
| `ops-framework/config/flows/zca_ops_flwtil.csv` | ZCA_OPS_FLWTIL | AREA | area |
| `ops-framework/config/check_registry.csv` | ZCA_OPS_CHECK | whole file | pack |
| `ops-framework/config/param_areas.csv` | ZCA_PARAM_AREA | whole file | loader ZCL_CA_OPS_PARAM_SEED |
| `ops-framework/config/param_definitions.csv` | ZCA_PARAM_DEF | whole file | loader ZCL_CA_OPS_PARAM_SEED |
| `ops-framework/config/licensing/alert_rules_license.csv` | ZCA_OPS_ALRULE | whole file | pack |
| `ops-framework/config/demo/alert_channels_demo.csv` | ZCA_OPS_ALCHN | whole file | pack |
| `ops-framework/config/demo/alert_rules_demo.csv` | ZCA_OPS_ALRULE | whole file | pack |
| `ops-framework/config/demo/param_areas_demo.csv` | ZCA_PARAM_AREA | whole file | pack |

## Blank-slate rules

- Scanned: `param-framework`, `ops-framework` minus the distribution exclusions and the folders tests, qualification, deps, node_modules, __pycache__; worked examples (`examples`) of a fictitious customer excepted from the column rule.
- E-mail addresses only of example.com, example.org, example.net.
- Customer columns of delivered CSV files empty, neutral ('', '*', 'OPS FRAMEWORK'), a placeholder or a product name: BUKRS, HBKID, HKTID, HKONT_FROM, HKONT_TO, BANKL, BANKN, IBAN, DESTINATION, ESCALATION_DEST, OWNER, BACKUP, TEAM, APPROVED_BY, SCHED_JOB, SCHED_FOLDER, SAP_PATTERN, JOBNAME, RUNBOOK_URL, AUTH_ROLE, LOGSYS, SOURCE_SYSTEM.
- Production code names no foreign object (`^Z(?:CL|IF|CX|BP_R|R|C|I|A|UI|E|D)_[A-Z0-9_]+$` outside the product names) and no append field (`^ZZ[A-Z0-9_]*$`).
- The first customer's deny list (objects, append fields, scheduler names, areas, roles, recipient lists) is built by the root test `tools/tests/test_blank_slate.py`, never stored in the product.

## Namespace

- Product names: `^ZCA$`, `^ZCA_`, `^Z_CA_`, `^Z(?:CL|IF|CX)_CA_`, `^ZBP_R_CA_`, `^Z(?:R|C|I|A)_CA_`, `^ZUI_CA_`; registered namespaces: none - decision R1-D1 (2026-11-15): stay in the Z namespace with the prefix ZCA; the namespace report is preparation only.
- Proposal `/XYZ/`, limits `ops-framework/release/object_limits.csv`, rename rules:

  - `^ZCL_CA_(.+)$` -> `/{ns}/CL_\1`
  - `^ZIF_CA_(.+)$` -> `/{ns}/IF_\1`
  - `^ZCX_CA_(.+)$` -> `/{ns}/CX_\1`
  - `^ZBP_R_CA_(.+)$` -> `/{ns}/BP_R_\1`
  - `^ZUI_CA_(.+)$` -> `/{ns}/UI_\1`
  - `^Z(R|C|I|A)_CA_(.+)$` -> `/{ns}/\1_\2`
  - `^Z_CA_(.+)$` -> `/{ns}/\1`
  - `^ZCA_(.+)$` -> `/{ns}/\1`
  - `^ZCA$` -> `/{ns}/`

## Objects abapGit does not serialize

- srvb: one binding <service definition>_O4 per service definition (not serialized by abapGit; created and published in ADT) - one binding <service definition>_O4 per service definition (not serialized by abapGit; created and published in ADT)
- balobj: ZCA_OPS - Application log object (SLG0), sub-object ALERT
- smtg: ZCA_OPS_ALERT_DEFAULT - E-mail template (SMTG), optional
- role: Z_CA_OPS_* - Role proposal names Z_CA_OPS_* and Z_CA_PARAM_* (PFCG, built by the customer)

## Distribution

Excluded from the distributable set:

- `param-framework/config/customer_terms.txt`
- `ops-framework/config/customer_terms.txt`
- `ops-framework/config/customer_terms_allowed.txt`
- `param-framework/tools/tests`
- `ops-framework/tools/tests`
- `ops-framework/release/qualification`

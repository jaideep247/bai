# Release and install baseline

> **First principle:** a release is a list of what ships, in which order, on what it stands and what it must never
> carry - and every line of that list is proven twice: offline against the sources, and on a clean system against SAP.
> **Analogy:** a packing list checked at the loading bay - every box on the list is on the pallet, every box on the
> pallet is on the list exactly once, the heavy boxes go first, and nothing addressed to the previous customer is on
> board; the delivery note signed at the door (the install run's evidence) is what counts, not the list.

Build M of Release 1 (`docs/release/RELEASE_1_PLAN.md` of the repository, review finding 1 "Prove the blank-slate
install first"). This document covers the release manifest, the blank-slate rule, the import order, the collision
and namespace report, upgrade and rollback, and the install harness. The configuration after the install (areas,
roles, SLG0, parameters, seed rows) stays in `docs/INSTALL.md`; this document does not repeat it.

| What | Where |
|---|---|
| Manifest (machine-readable) | `release/manifest.json` |
| Manifest (generated document) | `release/MANIFEST.md` - never edited, `python3 tools/release_manifest.py` |
| Length limits per object type | `release/object_limits.csv` (VERIFY where unsure) |
| Validation (house check `release_manifest`) | `python3 tools/release_manifest.py --check` (also in `tools/checks.py`) |
| Object, pack and namespace report | `python3 tools/release_manifest.py --report <folder>` (not committed) |
| Upgrade notes between two revisions | `python3 tools/release_diff.py <old> <new> [--out file]` |
| Install harness (a real system) | `../tools/qualify/qualify.py`, Windows `../tools/qualify/run.ps1` |
| Evidence of install runs | `release/qualification/<release>/<UTC>/` (`summary.md`, `results.json`, raw answers) |
| VERIFY items | `docs/VERIFY.md` V200-V212 |

## 1. The release manifest

`release/manifest.json` is the versioned pack manifest of the product (parameter framework + operations framework).
It names:

- **Supported releases**: S/4HANA 2023 (SAP_BASIS 758, S4CORE 108 - V201) on-premise / private edition is the
  *target*; S/4HANA 2025 with FI-CA (reference system A4H) is a *reference* - the first install proof route, not a
  supported target until qualified on its own.
- **Components with versions**: `ZCA_PARAM` 1.1.0 (`ZIF_CA_PARAM_TYPES=>GC_VERSION`) and `ZCA_OPS` 1.0.0
  (`ZIF_CA_OPS_TYPES=>GC_VERSION`, needs `ZCA_PARAM` >= `GC_PARAM_MIN_VERSION` 1.1.0). The check reads the constants:
  a version in the manifest that differs from the code fails.
- **Prerequisites**: abapGit and ADT; Basis steps (SLG0 object, optional SMTG template, SO23 lists and PFCG roles of
  the customer, SSF only for a licence); the SAP standard tables the product reads (`config/ddic/standard_tables.txt`);
  FI-CA dictionary objects for the objects that read them (V202).
- **Packs** - the delivery units, in import order:

| Pack | Status | Objects | Content |
|---|---|---|---|
| `PARAM` | release, required | `param-framework/src`, `src/ui` | the parameter framework |
| `CORE` | release, required | `ops-framework/src`, `src/ui` | the framework; licence modules CORE, CONTROL, ONBOARD, JOBS, RESPONSE, LINKS, PAYMODEL; catalogue package S4CORE; plug-in contracts of checks, jobs, alerts, purge |
| `FICA_CASH` | release | none of its own (decision D-M1) | **FI-CA Cash Operations**: catalogue package FICA with the qualified processes payment run, payment lots, returns, bank statement to lots, clearing / reset, reversal, G/L transfer; link layer FICA; break rules; account flow templates; modules CATALOGUE_FICA, BREAKS, FLOW; contract FLOW_SOURCE |
| `FSCD_STANDARD` | later | none | catalogue package FSCD (delivered, every monitoring row inactive; not claimed in Release 1) |
| `DEMO` | release, never production | `ops-framework/src/demo` | demo consumer for a sandbox |

- **Seed data per pack**: every row of every delivered seed file belongs to exactly one pack - by its key column
  (catalogue package, process / rule prefix, monitoring area, link layer) or as a whole file (check registry,
  parameter seed, licence alert rule, demo rows). Seed rows are configuration entered in a customizing request after
  the install (`docs/INSTALL.md`); the harness never writes them.
- **Source contracts**: the plug-in points of `config/extension_points.json` (interfaces a customer implements) by pack.
- **Checks**: the check classes of the check registry and of the catalogue monitoring rows by pack, each in a licence
  module the pack reaches.
- **Activation steps and fixtures** per pack (ABAP Unit, worked examples, offline fixtures; the demo scorecard
  fixtures of build N join `FICA_CASH`).
- **Open items**: `FICA_CASH` blocks the token `TFK033D` until V161 is closed - no product object reads the
  posting-area mapping (V161 is an item of the first consumer's mapping, not of the product; the check proves that no
  pack of the product is affected).
- **Licensing**: activation never depends on a licence; `LIC_ENFORCE` is delivered `W` (checked).

**Membership by rules.** An object belongs to the pack whose name rule matches it, otherwise to the pack that names
its folder; a seed row by its key; a licence module or plug-in contract no pack names belongs to `default_pack`
(`CORE`). A new object, row, module or contract therefore needs no manifest edit unless it belongs elsewhere - add a
name rule (`objects.names`) or name the module / contract in its pack.

`python3 tools/release_manifest.py --check` (house check `release_manifest` of `tools/checks.py`) fails when: a
component's version differs from its constant; an object of `src/` is in no pack or in two; two components deliver
the same object; a name is not a product name or not in Z / Y; a name is longer than its type's limit; two objects
share one name space (tables, data elements and CDS entities; classes and interfaces); the import order puts a pack
before its prerequisite; an object refers to an object of a pack it does not stand on; a licence module is unknown,
in two packs or needs a module the pack cannot reach; `LIC_ENFORCE` is not delivered `W`; a qualified catalogue
process is not in its package; a contract or check class is not a product object; a seed row is in no pack or in
two; an object uses a blocked token; a fixture is missing; a blank-slate rule (section 2) is broken; or
`release/MANIFEST.md` is out of date.

## 2. Blank slate: no first-customer data in the product

Rule: the parameter framework and the operations framework install and activate with **no** first-customer table,
append field, scheduler name, source code, recipient list, company code, house bank or object. Two checks:

1. **Product rules** (offline, inside the product; `release_manifest --check`): no e-mail address outside
   `example.com` / `.org` / `.net`; in every delivered CSV file (worked examples of the fictitious customer XX
   excepted) the customer columns (company code, house bank, accounts, recipient lists, owners, approvers, scheduler
   job / folder / pattern, runbook URL, role, logical system) are empty, `*`, `OPS FRAMEWORK`, a placeholder `‹...›`
   or a product name; production code names no foreign Z object (a class, interface, CDS or BDEF prefix outside the
   product's `CA` names) and no append field (`ZZ...`); delivered configuration names no append field.
2. **Deny list of the first customer** (root test `tools/tests/test_blank_slate.py` of the repository, never part of
   the product): it reads the first consumer's folder and builds the list there - its object names and object
   prefixes, append fields, scheduler jobs and patterns, parameter areas, roles, recipient lists, own tables and
   e-mail addresses - and scans the distributable set (component folders minus `distribution.exclude`) and the shared
   tools. The words stay in the test's run, never in a product file.

Found and removed on 2026-11-15 (build M): 74 modification-log lines that named the first consumer's former object
names ("Moved from <its class> to the reusable framework" - now "Moved from the first consumer ..."), including the
parameter seed template; an example parameter area with the first customer's abbreviation (now `ZXX_OPS`, parameter
framework README, builder header, a CDS comment); two test-history lines naming its parameter area and a test line
naming its posting-area table; the change-log line naming its authorisation objects (and its allowlist entry); test
e-mail addresses on a real domain (now `example.com`).

**Distributable set.** `distribution.exclude` of the manifest keeps out of a delivery: the term lists
`config/customer_terms.txt` of both components and the allowlist (they name the first customer's banks, systems and
prefixes on purpose - house check `customer_terms`; a commercial delivery ships an empty list, decision D-M3), the
offline tool tests and the evidence folder `release/qualification`.

## 3. Import order

**PARAM -> CORE -> FICA_CASH -> FSCD_STANDARD -> DEMO** (derived from the packs' `requires` and checked against
`import_order`). Components: `ZCA_PARAM` before `ZCA_OPS` (the framework reads `ZIF_CA_PARAM*` and the parameter
tables; the parameter framework names nothing of the framework - checked object by object). Within a component the
harness writes tables first (DDL sources of `ddic/`), then the types interface, exception classes, interfaces, CDS
views, access controls, metadata extensions, behaviour, services, classes and programs, and activates the component
in one mass activation; abapGit orders its own pull. `FICA_CASH` and `FSCD_STANDARD` are content: their order matters
for the seed rows (catalogue package rows before process rows, the FICA link layer before the FS-CD processes).

Note on activation prerequisites: some `CORE` objects read FI-CA tables (`DFKKOP`, `DFKKOPK`, `DFKKKO`, `DPAYH` -
account flow, link query, catalogue); the core therefore activates only where the FI-CA dictionary exists (V202;
`--report` lists the standard tables per pack and object).

## 4. Object collision and namespace

**Decision R1-D1 (2026-11-15): the product stays in the customer namespace with the prefix `ZCA`; no vendor
namespace is registered for now.** The real risk is therefore a name clash in the customer's Z space:

- **Offline**: no duplicate across components, no two objects in one name space, every name a product name within
  its limit (section 1).
- **On the target system** (harness stage `collision`, before anything is written): every product object name is
  looked up in TADIR (read-only data preview); an object with the same name and type - or a type of the same name
  space (a table, data element, CDS entity or view; a class or interface) - in a package outside the target packages
  is a clash. The run stops, writes nothing and lists the clashes (`collision.json`, `summary.md`). If TADIR cannot be
  read the run stops too: no proof, no write (V203, V209).

**Namespace report - preparation only, nothing is renamed.** `python3 tools/release_manifest.py --namespace /XYZ/`
applies the rename rules of the manifest (e.g. `ZCL_CA_OPS_STORE` -> `/XYZ/CL_OPS_STORE`, `ZCA_OPS_RUN` ->
`/XYZ/OPS_RUN`) and the limits of `release/object_limits.csv`. Snapshot of 2026-11-15 (671 names): 669 stay within
their limit; 2 would break - the authorization object class `ZCA` (4 characters, no namespace fits) and the table
`ZCA_OPS_EXC_HIST` (17 > 16). Service bindings, SLG0 objects, SMTG templates and roles are not serialized; their
names change too and are listed under *manual objects*. Limits marked VERIFY: programs 40, service bindings 26, SLG0
object 20, SMTG template 60, namespace 5-10 characters (V204).

## 5. Upgrade replay and rollback

**Upgrade notes.** `python3 tools/release_diff.py <old> <new>` reads git only and writes the notes: component
versions (a component whose objects changed while its version constant did not is flagged), objects added / changed
/ removed per pack, dictionary changes of tables, data elements and domains, changed configuration and manifest
files, and the rollback of each change. Table changes are classified:

| Class | Changes | Before the import |
|---|---|---|
| adjust | new table, new non-key field, longer CHAR / NUMC field | none (SE14 adjusts) |
| convert | key changed, field removed, type or decimals changed, field shorter, shorter data element / domain | export the table, plan the conversion window |
| drop | table removed | export the table, or keep it (decision) |
| settings | data class, delivery class, logging | none |

**Upgrade replay** (V206): in a sandbox, install the previous release with the harness from a checkout of its tag
(`git worktree add ../bai-<old> <tag>`, run the harness there with the same `--package-root`), enter its seed rows,
then run the harness from the new release in the same packages, compare the evidence of both runs and the upgrade
notes, and confirm every *adjust* happened without conversion and the stored rows survived.

**Rollback** (V207): transport-based. Before an upgrade in a landscape, release a transport of copies of the
previous versions of every object the notes list (or keep the previous tag's abapGit ZIP); a rollback imports it and
activates. Objects added by the release stay unused or are deleted with the rollback transport. A *convert* or *drop*
needs the table export taken before the upgrade. Configuration is rolled back by effective-dated activation
(catalogue activation rows from a date with reason and approver; monitoring rows set inactive), never by deleting
history. Licensing: `LIC_ENFORCE` back to `W` if a module is refused by mistake.

## 6. The install harness (a real system - the user runs it)

`../tools/qualify/qualify.py` installs **PARAM then CORE** (DEMO only with `--with-demo`; never a consumer) into the
packages the user names, through the ADT REST API, then activates and runs ABAP Unit, ATC, the CDS / OData checks and
the licensing proof. It is adapted from the qualification harness of the owner's test-tool repository (`ci/qualify`;
the attribution is in the header of `qualify.py`), whose ADT calls are proven on A4H; every new endpoint is VERIFY
V203. Standard library only (Python
3.13 on Windows).

Stages: `preflight` (manifest check, object list) - `connect` - `packages` (exist; the harness never creates
packages) - `collision` (section 4; stops the run) - `ddic` (domains, data elements, message classes, authorization
objects present: the harness does not create them - import the component with abapGit first) - `tables` - `sync` -
`texts` - `messages` - `settings` - `activate` (component by component) - `inventory` (installed version constants)
- `aunit` - `atc` - `cds` (every CDS, access control, metadata extension, behaviour and service source exists and is
active) - `odata` (every binding `<service definition>_O4` answers its OData V4 metadata; bindings are created and
published by hand in ADT - V210) - `licensing` (no licence installed, `LIC_ENFORCE` W or not set, every product object
active and ABAP Unit green: **activation proven separately from licensing**, V208).

Safety: `--package-root` and `--transport` are mandatory; a writing stage needs `collision` in the same run;
`--dry-run` only reads (no write, activation, ABAP Unit or ATC run); every write goes through a guard that accepts
only the ADT paths of the run's own objects (a create on a collection only with one of their names in the body); the
harness has no call that writes table contents - no business data, no configuration rows. Package mapping:
`--package-root ZCA` keeps `ZCA_PARAM`, `ZCA_PARAM_UI`, `ZCA_OPS`, `ZCA_OPS_UI`; `--package-root ZR1` gives
`ZR1_PARAM`, `ZR1_PARAM_UI`, `ZR1_OPS`, `ZR1_OPS_UI`; `$ZR1` local packages with `--transport LOCAL`.

**Recommended first install on a sandbox:**

1. Create the target packages in the sandbox (SE21 / ADT, software component and transport layer; `_UI` under its
   parent) and a modifiable transport request.
2. Import the parameter framework, then the framework, with abapGit (offline ZIPs, `docs/INSTALL.md` section 1) into
   those packages - abapGit creates every object type; or let the harness write the sources and use abapGit only for
   the types it does not create (stage `ddic` tells which).
3. Run the harness: first `--dry-run`, then the full run.

**Windows** (PowerShell, in the same window - no nested `powershell.exe`):

```powershell
setx ZCA_TT_A4H_URL "https://<host>:<port>"   # once; also ZCA_TT_A4H_USER, ZCA_TT_A4H_PASSWORD, ZCA_TT_A4H_CLIENT
setx ZCA_TT_A4H_TLS_PIN "<sha256 of the system's certificate>"   # self-signed test system only
Set-ExecutionPolicy -Scope Process Bypass
.\tools\qualify\run.ps1 -PackageRoot ZR1 -Transport A4HK900123 -DryRun
.\tools\qualify\run.ps1 -PackageRoot ZR1 -Transport A4HK900123
.\tools\qualify\run.ps1 -PackageRoot ZR1 -Transport A4HK900123 -Stages "preflight,connect,inventory,licensing"
```

(`run.ps1` reads the variables from the user environment also when they were set after the window opened; the
password goes to the child process only.) Linux / macOS: `SAP_URL`, `SAP_USER`, `SAP_PASSWORD`, `SAP_CLIENT`
(optional `SAP_TLS_PIN`), then `python3 tools/qualify/qualify.py --package-root ZR1 --transport A4HK900123`.

**What evidence counts.** A run counts as the install proof of a release when its `results.json` shows the release
and component versions of the manifest, the system and client, no `--only` restriction, `writes` > 0 or every object
unchanged, and **pass** in `collision`, `activate`, `inventory`, `aunit`, `atc` (the landscape's variant and
priority), `cds`, `odata` and `licensing` - on the target release for the release claim (V200), on A4H as the
reference proof. `summary.md` is the human view; the raw answers (`activation-*.xml`, `aunit-result.xml`,
`aunit-junit.xml`, `atc-worklist.xml`, `collision.json`, `objects.csv`) are kept with it. Evidence of a reference
system is committed under `release/qualification/`; evidence of a customer's system goes to that customer's release
pack, not to the product (decision D-M5).

## 7. Decisions

| ID | Decision | Proposal |
|---|---|---|
| R1-D1 | Vendor namespace | **Decided 2026-11-15: stay in Z with the prefix ZCA.** Collision test on every target system before install; namespace report kept as preparation |
| R1-D2 | Distribution route | **Decided 2026-11-15: abapGit (offline ZIP per component, this document and the harness) for pilots; SAP Add-On Assembly Kit later - it needs a registered namespace first (R1-D1 reopened then, V212)** |
| D-M1 | FI-CA Cash Operations as a content pack (no own ABAP package) | Yes for Release 1: its code is part of the core and licensed by module; split FI-CA-specific objects into a sub-package only when a system without the FI-CA dictionary must be supported (V202) |
| D-M2 | First product release number | 1.0.0 with `ZCA_PARAM` 1.1.0 and `ZCA_OPS` 1.0.0; from then on every release raises the version constant of a changed component (`release_diff` flags it) |
| D-M3 | Term lists in a delivery | Ship an empty `customer_terms.txt` (header only) in a commercial delivery; the first customer's terms stay in the repository |
| D-M4 | Demo pack | Sandbox only (`--with-demo`); never imported into production |
| D-M5 | Where evidence lives | Reference-system runs in `release/qualification/`; customer-system runs in the customer's release pack |

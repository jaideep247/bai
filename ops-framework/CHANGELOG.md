# Changelog

All notable changes of the operations framework (`ops-framework/` in jaideep247/bai).

## [Unreleased] - 2026-11-15 (licence installation role)

### Changed
- Decision D-L5: the vendor's licence is installed with the existing configuration role `Z_CA_OPS_CONFIG` (`ZCA_OPS`
  01 / 03 for `CA_OPS`); the proposed role `Z_CA_OPS_LICENSE` is dropped (`docs/auth_zca_ops.md`, `LICENSING.md`, INSTALL).
## [Unreleased] - 2026-11-15 (build M: clean install and release baseline)

Release constant unchanged (1.0.0): no ABAP logic changed (comments and test data only).

### Added
- Versioned pack manifest `release/manifest.json`: supported releases (S/4HANA 2023 target, S/4HANA 2025 reference),
  components with their version constants, prerequisites, packs PARAM / CORE / FICA_CASH (FI-CA Cash Operations) /
  FSCD_STANDARD (later) / DEMO with their objects (by rules), catalogue processes, licence modules, source contracts,
  check classes, seed rows by key, open item V161, activation steps and fixtures; import order; blank-slate,
  namespace and distribution rules. Generated document `release/MANIFEST.md`; limits `release/object_limits.csv`.
- `tools/release_manifest.py` (engine `../tools/abaptools/release_manifest.py`): `--check` (house check
  `release_manifest` of `tools/checks.py`), `--report <folder>` (objects, packs, standard-table prerequisites,
  namespace), `--namespace /NS/` (preparation only - R1-D1: the product stays in Z with the prefix ZCA).
- `tools/release_diff.py` (engine `../tools/abaptools/release_diff.py`): upgrade notes between two git revisions -
  objects per pack, dictionary changes classified adjust / convert / drop / settings, configuration files, versions,
  rollback guidance.
- Install harness `../tools/qualify` (adapted from the owner's test-tool harness): PARAM then CORE into the user's
  packages, name clash test against TADIR before any write, activation, ABAP Unit, ATC, CDS / OData, licensing proof
  without a licence; evidence in `release/qualification/<release>/<UTC>/`.
- `docs/RELEASE_AND_INSTALL.md`; VERIFY V200-V212; decisions R1-D1 / R1-D2 recorded, D-M1 ... D-M5 proposed.

### Changed
- Blank slate: the modification-log lines "Moved from <first consumer's object> to the reusable framework" name no
  consumer object any more (74 lines, sources and the parameter seed template); a test-history line and a test
  comment no longer name the first consumer's parameter area and posting-area table; a CDS comment uses the example
  area `ZXX_OPS`; test e-mail addresses on `example.com`; the change-log line of release 1.0.0 that named the
  consumer's authorisation objects is neutral and its allowlist entry removed.
## [Unreleased] - 2026-11-15 (build N: FI-CA cash coverage)

Release 1 build N (`docs/release/RELEASE_1_PLAN.md`): runnable checks of the FI-CA Cash Operations pack on SAP
standard tables, with expected / observed / unknown apart and the exception content of the pack on every finding.

### Added
- Sub-package `ZCA_OPS_CASH` (`src/cash`, `config/repository.json`): six check classes `ZCL_CA_OPS_CHK_CASH_PAYRUN`,
  `_PAYLOT`, `_RETURN`, `_EBS`, `_CLEAR`, `_GLKEY` (payment run expected / completed and proposal gap, payment lot
  posting and clarification, returns lot and reversal pending, bank statement arrival / stale source / posting /
  transfer to FI-CA, clearing reset and payment reversal after payout, reconciliation key open / error / not in the
  G/L); data access `ZIF_CA_OPS_CASH_DAO` / `ZCL_CA_OPS_CASH_DAO` (every count, sum and oldest date on the database,
  capped, a read error = message 521); the G/L header view `ZI_CA_OpsCashJrnl` on `I_JournalEntry`; the exception
  builder `ZCL_CA_OPS_CASH_EXC` (typed exception, one mapping into the finding); the run context
  `ZCL_CA_OPS_CASH_CTX` (business calendar window, owner from the control register, next cutoff in
  `CONTROL_TIME_ZONE`, "not evaluated", cap); factory / injector; types `ZIF_CA_OPS_CASH_TYPES`.
- Catalogue monitors `FICA_CASH_*` with their class in `config/catalogue/packages/fica.json` (registry and control
  coverage rows regenerated, inactive); licence module `CASH_OPS` (module map regenerated); messages 500-539;
  parameters `CASH_*` (prefix registered in `ZCL_CA_OPS_PARAMS`); VERIFY V220-V237.
- Offline fixture spec `config/cash/fixtures.json` (30 scenarios incl. the failure injection "job finished, output
  incomplete") validated by the root test `tools/tests/test_cash_fixtures.py`; ABAP Unit tests per class.
- `docs/FICA_CASH_OPERATIONS.md`.

### Changed
- Exceptions app list (`ZC_CA_OpsException` metadata extension, annotations only): columns Currency and Business date.
- `tools/abaptools/licensing.py`: check class sources are found in sub-packages of `src/` too.
- Catalogue `FICA` / `FSCD` (facts of the user's test tool, reference system A4H): `FICA_PAYRUN_NOPAY` counts
  payments only (`XVORL` blank, still V129); step names `FPVA`, `FP04M` (evidence C), `RFKKFIKEYCLOSE`
  (user), `RFKKGL00`, `RFKKKA00`, `FPINTM1`, mass activity type `PAYP` (still V127).

## [Unreleased] - 2026-11-15 (build I: field references checked against a reference system)

Evidence: the dictionary of 46 SAP standard tables of a reference system (S/4HANA 2025 with FI-CA; the product
targets S/4HANA 2023) exported by a consumer with `ddic_export.py export`. A field present there is used (noted as
seen on the reference system); a field missing there is treated as wrong.

### Added
- `tools/abaptools/ddic_export.py`: a scanner of the repository's code (`code_references`): ABAP SQL (FROM / JOIN with
  aliases, `alias~field`, the unqualified fields of a query with one data source and no join - field list, FIELDS,
  left-hand side of WHERE / HAVING, GROUP BY, ORDER BY), `TYPE <table>-<field>`, components of variables typed with
  a table (`TYPE <table>`, `TABLE OF <table>`, LOOP AT / READ TABLE rows, method parameters, class attributes,
  `VALUE #( )` / `VALUE <table>( )` rows) and CDS view entities (`select from` / joins / associations with aliases,
  `Alias.field`, unqualified fields of a branch with one source). Only tables with an export are judged; an alias or
  a variable that may stand for more than one table is "unresolved", never MISSING; customer fields (ZZ / YY) missing
  from an export are reported, not failed. `compare` prints a "code references" section with file:line, takes several
  `--exports` folders and `--open` lists (fields that stay read under a VERIFY item), and exits non-zero on a MISSING
  field of the registry, the catalogue or the code; `check_folders` / `export_folders` for a consumer's portable
  check. Unit tests in `tools/tests/test_ddic_export.py`.
- Link registry object `FICA_SUMMARY_TOTALS` (`DFKKSUM`: FIKEY, BUKRS, HKONT, WAERS, BUDAT) and the links
  `FICA_SUMMARY_TO_TOTALS` (1N) / `FICA_TOTALS_TO_SUMMARY` (N1) by FIKEY.

### Changed
- Every table field of the link registry layers S4CORE and FICA is evidence C (seen on the reference system):
  `FEBKO-BUKRS / HBKID / HKTID`, `FEBEP-VGEXT`, `DFKKCR-HBKID / HKTID`, `DPAYH-HBKID`, `TFK042Z-LAND1 / ZLSCH`
  (V117, V138). `FICA_SUMMARY_RECORD` (`DFKKSUMC`) is the reconciliation key with its status fields `XCLOS`,
  `CLDAT`, `XERRO`; document -> key is N1, key -> documents 1N (`DFKKSUMC` key is FIKEY).
- Process catalogue: field names filled where the data element names the meaning - `DFKKZK-ERDAT`,
  `DFKKRAPT-STDAT`, `DFKKKO-CPUDT`, `DFKKINVBILL_H-INVSTATUS`, `DFKKOP-FAEDN / STUDT / AUGST`, reconciliation key
  status table `DFKKSUMC` (`CPUDT`); the table rows confirmed on the reference system lose their VERIFY marker. Values
  stay placeholders, the rows stay pending (V128). `docs/LINK_REGISTRY.md` section 8 counts (FICA 9 objects, 35
  fields, 22 links, 18 active), `docs/PROCESS_CATALOGUE.md` table list.
- `docs/VERIFY.md`: V58, V59, V117, V128, V129, V135, V138, V146 record what the reference system shows, including
  the indexes (e.g. no secondary index on `FEBEP-CHECT`, `DFKKCR-DOC1R`, `DFKKRP-SELW1`, `DFKKOP-AUGDT`; `DPAYH` H8H
  on DOC1R; `DFKKOP` HTH on AUGBL; TBTCO without STATUS + ENDDATE).

### Fixed
- `FICA_PAYMENT_RUN` (`DPAYH`) named `BUKRS` and `PYMET`, which DPAYH does not have: now `BBUKR` (paying company
  code, `BUKRS_PAY`) and `RZAWE` (`PYMET_KK`); catalogue `FICA_PAYRUN_NOPAY` reads the company code from `BBUKR`.
- `FICA_SUMMARY_RECORD` (`DFKKSUMC`) named `BUKRS`, `HKONT`, `WAERS`: they are fields of the totals table `DFKKSUM`
  (new object above); the G/L transfer process lists `DFKKSUM` (totals) and `DFKKSUMC` (key status) instead of a
  placeholder.
- Catalogue `FICA_RET_OPEN` read the returns lot status from `DFKKRH` (returns history per business partner); the
  lot header is `DFKKRK` (`ERDAT`, `STARS`).
## [Unreleased] - 2026-11-15 (build J: licensing)

Goal (user, 2026-11-15): different processes can be activated or deactivated so that a customer runs a functionality
only when it pays for its licence - a vendor licence layer above the customer's own activation
(`docs/LICENSING.md`).

### Added
- Licensable modules `config/licensing/modules.json` (CORE - always included, never refused - CONTROL, ONBOARD, JOBS,
  RESPONSE, LINKS, CATALOGUE_FICA / _FSCD / _FSRI, PAYMODEL, BREAKS, FLOW) with entry points, check classes,
  configuration entities and gates; `license_module` of the catalogue packages (S4CORE -> CORE, FICA, FSCD; the FS-RI
  process on its own); generated module map `ZCL_CA_OPS_LIC_MAP` and `docs/licensing/modules.md`
  (`tools/licensing.py`, house check `licensing`, shared engine `../tools/abaptools/licensing.py`).
- Licence runtime: `ZIF_CA_OPS_LIC_TYPES`, `ZIF_CA_OPS_LICENSE` / `ZCL_CA_OPS_LICENSE` (factory `GET_LICENSE`,
  injector `INJECT_LICENSE`; verified once per run), pure decision `ZCL_CA_OPS_LIC_POLICY` (licensed / expiring / grace
  / expired / not licensed / binding / version / signature / missing), file reader `ZCL_CA_OPS_LIC_FILE` (PEM, asJSON
  payload), SSF / system adapter `ZIF_CA_OPS_LIC_PLATFORM` / `ZCL_CA_OPS_LIC_PLATFORM` (`SSF_KRN_VERIFY`,
  `SLIC_GET_LICENCE_NUMBER`, VERIFY V162 / V163), data access `ZIF_CA_OPS_LIC_DAO` / `ZCL_CA_OPS_LIC_DAO`; tables
  `ZCA_OPS_LIC` (active licence and history), `ZCA_OPS_LICM`, `ZCA_OPS_LICMOD` (display copies for the dashboard).
- Report `ZCA_OPS_LICENSE_INSTALL` (frontend or application server, test mode, `ZCA_OPS` 03 / 01 for `CA_OPS`).
- Licence check `ZCL_CA_OPS_CHK_LICENSE` (registry row `CA_OPS / LICENSE`, active): missing, invalid, expiring within
  `LIC_WARN_DAYS`, in grace, expired - owned exceptions alerted by the existing router; recommended alert rule
  `config/licensing/alert_rules_license.csv` (inactive).
- Dashboard `ZUI_CA_OPS_LIC`: `ZC_CA_OpsLicModule` (overview card: module, valid to, days left, state) and
  `ZC_CA_OpsLicense` (active licence and history), `ZI_CA_OpsLicCfg`, DCLs.
- Vendor tools `../tools/licensing/issue_license.py` (payload from arguments / JSON, validated against the module
  catalogue, signed with `openssl cms -sign -nodetach`, no key inside the repository) and `verify_license.py` (offline
  verification and the state per module); tests `../tools/tests/test_licensing.py` (throwaway key in a temporary
  directory, skipped without openssl).
- Parameters `LIC_ENFORCE` (W), `LIC_WARN_DAYS` (30), `LIC_SSF_PROFILE`, `LIC_FILE_PATH`, `LIC_FILE_NAME` (prefix
  `LIC_` in area `CA_OPS`); messages 350-366; VERIFY V162-V168.

### Changed
- Gates (refused only under `LIC_ENFORCE = X`; CORE never): `ZCL_CA_OPS_CHECK_RUNNER` (a check of an unlicensed module
  not run - `LICENSE_REFUSED`, its exceptions stay open; under W one warning `LICENSE_UNLICENSED` per run),
  `ZCL_CA_OPS_BRK_ANALYZER`, `ZCL_CA_OPS_FLOW_EVAL`, `ZCA_OPS_ESCALATE`, `ZCA_OPS_PILOT_EXPORT` (352 and a recorded red
  run, `ZCL_CA_OPS_RUN_GUARD=>REFUSE_LICENSE`), the sign-off of the daily control review.
- `ZUI_CA_OPS_CFG` (generated): activation of a row of an unlicensed module refused on save (350) - new check kind
  `module` of the shared RAP generator, checks `ZCL_CA_OPS_CFG_CHECKS=>MODULE_LICENSED`, `CAT_PROCESS_LICENSED`,
  `CLASS_LICENSED`, `PACKAGE_LICENSED`; deactivation always allowed.
- Stored data stays readable after a licence ends: no read app, no exception action and no stored result is blocked.

## [Unreleased] - 2026-11-15 (table definitions from the landscape)

### Added
- `tools/abaptools/ddic_export.py`: `export` fetches the definition, the fields (DD03L, incl. includes and appends)
  and the indexes (DD17S) of a list of tables through the system's ADT interface (dictionary metadata only, run on a
  machine that reaches the system); `compare` checks the field references of the link registry and the process
  catalogue against the exports (exists / missing / may sit in an include). Table list of the product:
  `config/ddic/standard_tables.txt`. Not yet run against a system (the ADT data preview answer format is read
  generically; correct the parser if a release differs).

### Changed
- Fields seen in the landscape's definitions of `DFKKKO`, `DFKKOP`, `DFKKOPK`: link registry fields
  `DFKKKO-STBEL`, `DFKKOP-AUGRD / BUKRS / GPART` evidence C (V117); V128 and V146 record what is confirmed and what
  stays open (sign of `BETRW`, partial clearing, stage rule values).

### Fixed
- Process catalogue `FICA_WO_REASON`: the write-off reason was read from `DFKKOP-ABGRD`; `ABGRD` is a field of the
  document header `DFKKKO`. The condition field is a placeholder until a source with reason and company code is
  chosen (V128); the check was delivered inactive and stays so.
## [Unreleased] - 2026-11-15 (build H: customer extensions)

Goal (user, 2026-11-15): a generic tool deployable at any customer landscape, plugged in with customer-specific data
tables to pull and amalgamate information, so that customer-specific data sits on top of what comes from the standard
tables (`docs/EXTENDING_WITH_CUSTOMER_DATA.md`).

### Added
- One customer extension contract: `docs/EXTENDING_WITH_CUSTOMER_DATA.md` (first principle, matrix module x standard
  data source x extension point x mechanism, decision tree, CDS extensions, the customer pack, steps, worked example,
  decisions D-H1, D-H2, D-H4 ... D-H7) and the inventory `config/extension_points.json` (27 extension points: 19
  configuration / registry / generated / plug-in points of the existing modules and 8 CDS extension points).
- Extensible product views (SAP CDS extensibility annotations, VERIFY V153): base views `ZC_CA_OpsException`,
  `ZR_CA_OpsBrkGroup`, `ZR_CA_OpsBrkItem`, `ZI_CA_OpsFlowCube`, `ZC_CA_OpsFlowStage`, `ZR_CA_OpsCheckStatus`,
  `ZR_CA_OpsCatalogue`, `ZC_CA_OpsCtlReview`; the elements pass on to `ZC_CA_OpsBrkGroup`, `ZI_CA_OpsBrkCube`,
  `ZC_CA_OpsBrkItem`, `ZC_CA_OpsCheckStatus`, `ZC_CA_OpsCatalogue`; the queries `ZC_CA_OpsBrkQry` / `ZC_CA_OpsFlowQry`
  are copied into the customer package (fallback, V155). Anchors per point (company code, journal line, assignment,
  object of a finding, check, stage, account, process, control). No element, join or behaviour of a view changed.
- Shared engine `../tools/abaptools/extensions.py` with the wrapper `tools/extensions.py` (house check
  `extensions`): the inventory against the views, documents and files; the generator of a customer pack
  (`config/extensions/*.json`: registry link or key of the customer's own object, fields with their sensitivity;
  only declared points and anchors, customer prefixes, "to one" links, every key mapped, registry fields only,
  hidden never, masked rendered masked, quota; active / pending / blocked) rendering `extend view entity` sources and
  query copies into the customer package or its pending folder, and a report; `--check`.
- Worked example of a fictitious second customer: `config/extensions/examples/xx` (six extensions: four active,
  one pending, one blocked), rendered into `docs/extensions/example_xx.md`; the example overlay of the link registry
  gained the customer tables it joins (`XX_REQUEST`, `XX_CTL_REGISTER`, `XX_STAGE_SLA`) and the inactive link
  `XX_GLITEM_TO_REQUEST`. No framework file names the example outside the example folders.
- Serializer: DDLS of an `extend view entity` (source type `E`, VERIFY V156; description from `// Extension:`).
- Tests: `../tools/tests/test_extensions.py` (inventory drift, every generator rule, rendering, the example and the
  first consumer's pack, no product file references a customer object), serializer test of an extension.
- Module documents name their extension points (break analysis, account flow, process catalogue, exceptions,
  control review, area dashboard); INSTALL C7 and section 6g; VERIFY V153-V157.

No ABAP code and no message changed (no new message number used).

## [Unreleased] - 2026-11-15 (build G: account flow reconciliation)

Goal (user, 2026-11-15): a reconciliation dashboard "Account flow" - stages as rows, accounts by role as columns,
debit / credit per cell, Movement, Opening, Closing and Unexplained, expected postings, control tags and tiles; both
flows (disbursements, collections), analytical query, posting date range; every figure from postings or open items of
existing checks (`docs/ACCOUNT_FLOW.md`).

### Added
- Configuration tables `ZCA_OPS_FLOW`, `_FLWACC`, `_FLWSTG`, `_FLWTIL`, `_FLWCTL`, `_FLWRUL` (entities of
  `ZUI_CA_OPS_CFG`, generated; reserved stage IDs, message 340), evaluation `ZCA_OPS_FLWEVL` / `_FLWEVI`; domains
  `ZCA_OPS_FLOW_TAG`, `_EVST`, `_ROW`, `_ROLE`.
- `ZIF_CA_OPS_FLOW_TYPES`, `ZIF_CA_OPS_FLOW_DAO` / `ZCL_CA_OPS_FLOW_DAO`, `ZCL_CA_OPS_FLOW_CONFIG` (cross-row rules),
  plug-in `ZIF_CA_OPS_FLOW_SOURCE` with the sources `ZCL_CA_OPS_FLOW_SRC_BREAK` (explained breaks),
  `ZCL_CA_OPS_FLOW_SRC_FICA` (open FI-CA items), `ZCL_CA_OPS_FLOW_SRC_FINDING` (open exceptions of the stage checks),
  `ZCL_CA_OPS_FLOW_EVAL`, report `ZCA_OPS_FLOW_RUN`; factory `GET_FLOW_DAO`, injector `INJECT_FLOW_DAO`.
- CDS over the released `I_JournalEntryItem` / `I_CompanyCode` / `I_FiscalCalendarDate` and the FI-CA documents:
  `ZI_CA_OpsFlowCfg`, `_Acct`, `_GlSig`, `_GlMin`, `_FiLine`, `_FiSig`, `_FiMin`, `_Move`, `_Open`, `_EvlMax`,
  `_EvlItm`, `_EvlAll`, `_PosU`, `_PosSum`, `_Pos`, `_Exp`, `_Ctl`, `_Tag`, `_StgTag`, `_Fact`, `_TileU`, `_TileS`,
  text views `_TagT`, `_EvStT`, `_RowT`, `_RoleT`; cube `ZI_CA_OpsFlowCube`, query `ZC_CA_OpsFlowQry`, tiles
  `ZC_CA_OpsFlowTile` and stage card `ZC_CA_OpsFlowStage` (service `ZUI_CA_OPS_FLOW`), DCLs.
- Product flows `DISB` / `COLL` (`config/flows`, area `CA_FICA`, inactive, no accounts); offline engine
  `tools/abaptools/flow_config.py` (check `flow_config`).
- Parameters `FLOW_LEDGER`, `FLOW_KEY_DATE_LAG`, `FLOW_RETENTION_DAYS`, `FLOW_BREAK_MAX_AGE_DAYS` (prefix `FLOW_`);
  messages 320-336, 338, 340; ABAP Unit and CDS tests; VERIFY V145-V149; PlanViz FLOW-PV1 ... FLOW-PV5.

## [Unreleased] - 2026-11-11 (build F: clearing-account break analysis, pilot pack)

Goal (user, 2026-11-11): SAP-native subledger operations and reconciliation evidence - read-only, no matching, no
postings (`docs/BREAK_ANALYSIS.md`, `docs/PILOT_PACK.md`).

### Changed (2026-11-12, process catalogue table names)
- FI-CA catalogue placeholders replaced by SAP standard table names from SAP documentation (evidence V, V128 until
  seen in SE11): invoicing `DFKKINVDOC_H` / `_I`, billing `DFKKINVBILL_H` / `_I`, interest history `DFKKIH`, write-off
  history `DFKKWOH` (G/L lines `DFKKOPK`), instalment plan `FKK_INSTPLN_HEAD`, correspondence `DFKKCOH` / `DFKKCOHI`.
  Date / status fields of the aggregates stay placeholders; every process and monitoring row stays inactive.

### Added
- Break analysis: configuration tables `ZCA_OPS_BRKACC`, `_BRKBKT`, `_BRKRUL`, `_BRKCND` (entities of `ZUI_CA_OPS_CFG`),
  snapshot `ZCA_OPS_BRKRUN` / `_BRKGRP` / `_BRKITM`; `ZIF_CA_OPS_BRK_TYPES`, `ZIF_CA_OPS_BRK_DAO` / `ZCL_CA_OPS_BRK_DAO`
  (ACDOCA grouped read with HAVING and cap, line read per package), `ZCL_CA_OPS_BRK_RULES` (pure, first match wins),
  `ZIF_CA_OPS_BRK_LINKS` / `ZCL_CA_OPS_BRK_LINKS` (link registry, set-based), `ZCL_CA_OPS_BRK_ANALYZER`, report
  `ZCA_OPS_BRK_RUN`, check `ZCL_CA_OPS_CHK_BREAK`, purge target `ZCL_CA_OPS_BRK_PURGE`; factory `GET_BRK_DAO`.
- CDS `ZI_CA_OpsBrkRunMax`, `_KeyMax`, `_Snap`, `ZR_CA_OpsBrkGroup` / `_Item` / `_Bucket`, `ZC_` projections and DCLs,
  cube `ZI_CA_OpsBrkCube`, query `ZC_CA_OpsBrkQry`, service `ZUI_CA_OPS_BRK` (list, lines, card by bucket).
- Product buckets and rules `config/breaks`; offline engine `tools/abaptools/break_rules.py` (check `break_rules`);
  catalogue monitoring template `FICA_GL_BREAKS`; link registry field `S4_BANK_STMT_LINE-VGEXT`.
- Pilot pack: `ZCA_OPS_PILOTBL` (baselines), reason code `NOT_AN_ISSUE`, CDS `ZI_CA_OpsPilotCfg`, `_PilotEp`,
  `_PilotDay`, `ZR_` / `ZC_CA_OpsPilot`, `ZR_` / `ZC_CA_OpsPilotBrk`, cube / query, service `ZUI_CA_OPS_PILOT`;
  `ZIF_CA_OPS_PILOT_TYPES`, `ZIF_CA_OPS_PILOT_DAO` / `ZCL_CA_OPS_PILOT_DAO`, `ZCL_CA_OPS_PILOT_CSV`, report
  `ZCA_OPS_PILOT_EXPORT`.
- Parameters `BRK_*`, `RETENTION_DAYS_BREAK`, `PILOT_*`; messages 280-294, 300-303; VERIFY V134-V138, V142, V143.

## [Unreleased] - 2026-11-11 (build F: explainable, versioned results)

Goal (user, 2026-11-11): every finding says which rule and which configuration produced it; a control sign-off is
reopened when a covered finding changes after it (`docs/EXPLAINABLE_RESULTS.md`).

### Added
- `ZCA_OPS_FINDING-CFG_VERSION` / `CFG_RULE` (configuration version and row of a finding), `BUS_DATE` / `EVENT_AT`
  (pilot metrics); `TY_FINDING-CFG_VERSION`, `CFG_RULE`, `EVENT_AT`; the store writes them (never inherited).
- `ZIF_CA_OPS_CHECK_CONFIG` (optional: a check's effective configuration rows), `ZCL_CA_OPS_CFG_VERSION` (SHA-1 of the
  sorted lines with the registry row); the runner stamps the version on every finding; `ZCL_CA_OPS_CHK_AGG` names its
  aggregate rows and sets `CFG_RULE`.
- Exceptions app: facet *Explanation* (check, rule, configuration rule, version, business date, event time).
- Control review: reopened sign-off with reason - domain `ZCA_OPS_REOPEN`, `ZI_CA_OpsReopenT`, `ZI_CA_OpsCtlReopen`,
  `ZI_CA_OpsCtlReopDay`; `IsReopened`, `ReopenReason`, counts per reason, counter `ReopenedCount`;
  `ZCL_CA_OPS_REVIEW_POLICY=>REOPEN_REASON` / `REOPEN_REASON_OF_SLICE`.
- Name prefixes `BRK_` and `PILOT_` read in area `CA_OPS`.

### Changed
- Awaiting review: a finding raised again unchanged after the sign-off no longer reopens it (before: any finding after
  the sign-off) - decision D-F1. VERIFY V132, V133.

## [Unreleased] - 2026-11-11 (process catalogue with activation)

Goal (user, 2026-11-11): choose which SAP standard processes are active at a customer (some use dunning or invoicing,
some skip standard processes) and fill the dashboard dynamically with the active processes only; SAP standard
processes and tables only, no customer-specific object in the framework (`docs/PROCESS_CATALOGUE.md`).

### Added
- Tables `ZCA_OPS_CATPKG` (packages S / I / C, rank, prefix, monitoring area), `ZCA_OPS_CATPRC` (processes: component,
  dashboard card, owner role, schedule, default, evidence), `ZCA_OPS_CATSTP` (steps: transactions, programs, mass
  activity types), `ZCA_OPS_CATTAB` (standard tables with their link registry object), `ZCA_OPS_CATDEP`
  (dependencies hard / soft), `ZCA_OPS_CATACT` (activation per customer, effective from a date, reason, approver);
  entities of `ZUI_CA_OPS_CFG` (generated) with checks on save, approver four-eyes (240,
  `ZCL_CA_OPS_CFG_CHECKS=>APPROVER_VALID`).
- `ZIF_CA_OPS_CAT_TYPES`, `ZIF_CA_OPS_CAT_DAO` / `ZCL_CA_OPS_CAT_DAO`, API `ZIF_CA_OPS_CATALOG` /
  `ZCL_CA_OPS_CATALOG` (effective state, definition, active processes, business processes not in effect, rule check;
  factory `GET_CATALOG` / `GET_CAT_DAO`, injector); generic risk check `ZCL_CA_OPS_CHK_OUTAGE` (accounting around an
  approved planned downtime, `ZIF_CA_OPS_DOWNTIME`); ABAP Unit for each, CDS tests `ZCL_CA_OPS_CAT_CDS_TEST`.
- CDS: `ZI_CA_OpsCatActLast`, `ZI_CA_OpsCatProcEff`, `ZI_CA_OpsProcEff`, `ZI_CA_OpsChkEff`, `ZI_CA_OpsChkProcOff`,
  `ZI_CA_OpsCtlProcOff`, `ZI_CA_OpsCatMon`, `ZI_CA_OpsProcKpi`, `ZI_CA_OpsProcAgg`; active business processes with
  their own KPIs `ZR_CA_OpsProcStatus` / `ZC_CA_OpsProcStatus` (DCL, OVP annotations) and the catalogue list
  `ZR_CA_OpsCatalogue` / `ZC_CA_OpsCatalogue` (DCL) in `ZUI_CA_OPS_DASH`.
- Product content: `config/catalogue/s4core.json`, `packages/fica.json`, `packages/fscd.json` (23 SAP standard
  processes, VERIFY V127-V129, monitoring templates inactive), worked example `examples/xx_layer.json`; generated
  seed rows `config/catalogue/seed`, monitoring rows `config/catalogue/monitoring`, `docs/catalogue/catalogue.md`.
- Shared engine `tools/abaptools/process_catalogue.py`, wrapper `tools/process_catalogue.py`, house check
  `process_catalogue`, tests `tools/tests/test_process_catalogue.py` of the repository.
- Parameters `CAT_OUTAGE_DAYS`, `CAT_OUTAGE_MARGIN_DAYS` (prefix `CAT_` read in area `CA_OPS`); messages 240-255.

### Changed
- `ZCA_OPS_PROC-CAT_PROCESS`: a business process names the catalogue process it monitors; it is in effect only while
  that process is active (an unknown name does not stop it - fail-open, onboarding error `CAT_REF_UNKNOWN`).
- Runner `ZCL_CA_OPS_CHECK_RUNNER`: checks of a business process not in effect are not run (information finding
  `PROCESS_INACTIVE`, 241); their open exceptions stay open.
- Onboarding check `ZCL_CA_OPS_CHK_ONBOARD`: only processes in effect are checked; catalogue findings
  `CAT_NO_CHECK`, `CHECK_PROC_INACTIVE`, `CAT_REF_UNKNOWN`, `CAT_DEP_INACTIVE`, `CAT_INVALID`.
- Area dashboard `ZI_CA_OpsChkSlice` (checks in effect only), `ZR_CA_OpsCheckStatus` / `ZC_` (+ catalogue process,
  dashboard card); daily review `ZI_CA_OpsCtlSlice` (a control of switched-off checks only is not expected).
- Aggregate rows (`ZCA_OPS_AGG`, `ZCL_CA_OPS_AGG_QUERY`): window `MAX_AGE_DAYS`, `TIME_FIELD`, operator `NI`, a date /
  time window for the outage check (255); scaffold `new_process.py` and offline check `onboarding.py` follow
  (`CAT_PROCESS`, `MAX_AGE_DAYS`, `TIME_FIELD`, a class that reads its aggregate rows).
- `docs/VERIFY.md` V124-V129; `docs/INSTALL.md` §6d, `docs/auth_zca_ops.md` (activation: no 85, four-eyes on save),
  `docs/PARAMETERS.md`, `docs/ADDING_A_BUSINESS_PROCESS.md`, `README.md`.

## [Unreleased] - 2026-11-11 (SAP component names, FICA layer)

User decision 2026-11-11: FI-CA, FS-CD, FICA, FSCD and EBS are SAP standard component names, not words of a
consumer.

### Changed
- `config/customer_terms.txt`: "FI-CA", "FS-CD", "FICA", "FSCD" and "EBS" removed (every other term, "payment
  engine" included, kept); framework documents may say FI-CA / FS-CD where that is the precise SAP term.
- Link registry: industry layer `CONTRACT` (contract accounting, ID prefix `CA_`) renamed to `FICA` (the SAP
  FI-CA / FS-CD standard layer, ID prefix `FICA_` - `CA_` was visually close to the framework prefix `CA`): spec
  `config/links/packages/fica.json` (was `contract_accounting.json`), every object and link ID (`FICA_OPEN_ITEM`,
  `FICA_ITEM_TO_CLEARING_HDR`, ...), the worked example `xx_overlay.json`, seed rows, lineage, CDS snippets and
  impact regenerated with `tools/link_registry.py`; `docs/LINK_REGISTRY.md`, `docs/INSTALL.md` §6c, V117. CDS
  association names derived from the IDs are unchanged (`_OpenItem`, ...). A system that already holds the seed
  rows of `CONTRACT` deletes them and creates the `FICA` rows (no ABAP object names a layer or link ID).

## [Unreleased] - 2026-11-11 (link registry)

Goal (user, 2026-11-11): custom fields and their links against different tables - how a custom field flows from one
table to another for each customer - as configuration on top of a generic framework and the SAP standard tables
(`docs/LINK_REGISTRY.md`).

### Added
- Tables `ZCA_OPS_LNKLYR` (layers), `ZCA_OPS_LNKOBJ` (business objects), `ZCA_OPS_LNKFLD` (object fields with
  sensitivity and evidence), `ZCA_OPS_LINK` (links: cardinality, evidence quality, fallback chain, replacement,
  activation), `ZCA_OPS_LNKCND` (conditions EQ / CONST / NOTINIT / PREFER with transforms), `ZCA_OPS_LNKACT`
  (activation overrides of a customer layer); entities of the configuration app `ZUI_CA_OPS_CFG` (generated) with
  checks on save: source and field against the runtime DDIC (082 / 083), condition references TABLE-FIELD (225,
  `ZCL_CA_OPS_CFG_CHECKS=>FIELD_REF_VALID`), allowed values (413), kind-dependent fields (235 / 236).
- `ZIF_CA_OPS_LINK_TYPES`, `ZIF_CA_OPS_LINK_DAO` / `ZCL_CA_OPS_LINK_DAO` (registry read; one validated read per link
  for a set of source rows through the approved tables `ZCA_OPS_TABWL` and `S_TABU_NAM`), `ZCL_CA_OPS_LINK_QUERY`
  (pure: WHERE from DDIC-checked names and quoted literals, transforms, attribution, PREFER, masking),
  `ZCL_CA_OPS_LINK_REGISTRY` (pure: validation, effective registry, fallback chains), `ZIF_CA_OPS_LINK_WALKER` /
  `ZCL_CA_OPS_LINK_WALKER` (bounded, set-based drill-down with path and evidence quality), registered check
  `ZCL_CA_OPS_CHK_LINKS`; ABAP Unit for each (doubles; OSQL doubles for the data access).
- Parameters `LINK_MAX_DEPTH`, `LINK_MAX_ROWS`, `LINK_MAX_NODES`, `LINK_READ_CHUNK` (prefix `LINK_` read in area
  `CA_OPS`); messages 210-236 of `ZCA_OPS`.
- Product layers `config/links/s4core.json` (S/4HANA core standard: released journal entry / item and company code
  views, bank statement, business partner) and `config/links/packages/contract_accounting.json` (contract accounting
  standard tables); worked example of a customer overlay `config/links/examples/xx_overlay.json` (prefix XX).
- Shared engine `tools/abaptools/link_registry.py` and the framework's wrapper `tools/link_registry.py`: validation,
  seed rows (`config/links/seed`), lineage (`docs/links/lineage.md`), CDS snippets, field impact; house check
  `link_registry`; tests `tools/tests/test_link_registry.py` of the repository.
- Payment model generator: a section's join may name a registry link (`{link, join, alias, from_alias}`, model key
  `links`, section key `join_layout`); text joins render unchanged.

### Changed
- `docs/VERIFY.md` V116-V120; `docs/auth_zca_ops.md`, `docs/INSTALL.md` §6c, `docs/PARAMETERS.md`,
  `docs/ADDING_A_CUSTOMER_PAYMENT_MODEL.md` §2a.

## [Unreleased] - 2026-11-11 (ledger model on released CDS views)

Goal (user, 2026-11-11): the G/L side of the ledger and document-change model reads SAP's released CDS views
instead of tables (clean core, upgrade-stable); a consumer's subledger reads stay table reads where no released
view exists.

### Changed
- Templates `templates/payment_model`: `ZI_<P>_LedgJrnl` reads `I_JournalEntryItem` with the header
  `I_JournalEntry`, the chart of accounts of `I_CompanyCode` and the account text `I_GLAccountText` (was the
  journal, document header, entry view, company code and account text tables); the posting key from
  `I_JournalEntryItem` (no entry-view join; fallback in VERIFY V110). `ZI_<P>_LedgGlDoc` finds the G/L documents of
  a batch key on `I_JournalEntry` (reference type + original reference document + company code; reverse document /
  year), `ZI_<P>_LedgAcctDay` aggregates `I_JournalEntryItem`, the G/L reversal branch of `ZI_<P>_DocEvtAll` reads
  the reversal document's header from `I_JournalEntry`. Output element names, the "reversed documents excluded"
  rule and the per-key / per-account-and-day aggregation unchanged - consuming views, services, DCLs, UI
  annotations and CDS tests keep working. The source views' DCL is not inherited (the product's projections keep
  their own DCL).
- Generated CDS tests: `ltc_acct_day` doubles `I_JournalEntryItem` (field by field); new `ltc_journal` (configured
  ledger only, header attributes, account text in the company code's chart of accounts, line of a reversed
  document flagged) and `ltc_gl_doc` (G/L documents of a batch key by reference type + key + company code, reversed
  document listed) double `I_JournalEntryItem`, `I_JournalEntry`, `I_CompanyCode`, `I_GLAccountText`.
- `docs/VERIFY.md` V110 (released views, C1 release state, element names, posting key fallback), V113 (PlanViz
  under the released views), V114 (new CDS tests); `docs/ADDING_A_CUSTOMER_PAYMENT_MODEL.md` §5 (released views;
  the consumer's subledger tables as a recorded clean-core exception).

## [Unreleased] - 2026-11-11 (customer-neutral product)

Goal (user, 2026-11-11): the framework and the shared tools stay generic; a customer's tables, fields,
middleware, banks, sources and schedulers live only in the consumer and are plugged in by configuration.

### Changed
- Check `customer_terms` reads every text file of the framework (src, ddic, docs, templates, config, tools,
  README, CHANGELOG) and of the shared tools `tools/abaptools` (test fixtures excepted); term flags `case`,
  `prefix` and `text` in `config/customer_terms.txt` (more middleware, feeder, bank, finance-system, field and
  status names and the consumer's object prefixes); allowlist `config/customer_terms_allowed.txt` (one entry,
  each entry with its reason; an unused entry fails). Check `layering` takes the consumer prefixes from the
  term list.
- `docs/VERIFY.md`: the first consumer's items V82-V93 moved to the consumer's own list (IDs unchanged);
  V97-V99 name the consumer's objects generically.
- Worked examples made fictitious: `docs/ADDING_A_BUSINESS_PROCESS.md` §10 (source `PORTAL`, prefix `XX`, a card
  payment provider), `docs/PARAMETERS.md` examples, the feeder text example of
  `docs/ADDING_A_CUSTOMER_PAYMENT_MODEL.md`; neutral wording in `docs/auth_zca_ops.md`,
  `config/zca_ops_messages.md`, a table comment and two source comments (definition sheet reference).
- Shared RAP generator `tools/abaptools/rap_generate.py`: working prefix `XX`, the app's prefix (or the
  profile's `PREFIX`) required - no consumer prefix as default. Generated files unchanged.

## [Unreleased] - 2026-11-11 (ledger and document-change model - product layer)

Goal (user, 2026-11-11): from a payment down to the universal journal, the subledger batch key as a level of its
own, a group reconciliation per business date / company code / account / currency, and the document changes
(reversal, clearing reset, re-clearing, void, reissue, G/L reversal) of a payment - generic, a customer's subledger
is a mapping.

### Added
- Contract sections `ledger_item`, `ledger_batch`, `recon_account`, `recon_result`, `recon_bank_line`,
  `document_event` and model keys `ledger` (ledger parameter) / `gl_reference_type`
  (`tools/abaptools/payment_model.py`; composite template conditions `A+B`, `#else`; tests in `tools/tests`).
- Templates (`templates/payment_model`): ledger parameter view, journal lines with every accounting attribute,
  G/L documents / totals of a batch key, batch key level, subledger item (partner masked), payment ledger with the
  payment's share of the summary, group reconciliation (live journal / subledger legs, stored result, bank lines and
  the reset / reversal bucket) with an analytical cube and query, bank statement line, change events with G/L
  reversals, payment and request change timelines, change volumes; facets Ledger and Changes on the payment page,
  Changes on the request page; DCL grants incl. the cube; CDS tests (share of the summary, currencies apart,
  reversed G/L documents excluded, batch key status, journal per account and day, old / new document link).
- Dimension `DOC_EVENT` of `ZCA_OPS_PMDIM` (texts of the change types). Guide section 5 of
  `docs/ADDING_A_CUSTOMER_PAYMENT_MODEL.md`; VERIFY V110-V114.

## [Unreleased] - 2026-11-11 (payment model product layer)

Goal (user, 2026-11-11): categorised, drillable payment views (business users, managers, IT support) sold to
several customers - the generic part is product, a customer's tables are a mapping spec.

### Added
- Payment model contract and product templates (`templates/payment_model`): cube per currency and flow, business-date
  trend with the same weekday of the previous week and peak days, payment drill-down list and object page, payment -
  request link (n:m), request object page with attempts, feeder timeline and masked feeder reference with deep link,
  exceptions raised vs resolved per day, persona card annotations, DCL with the company-code rule, service, CDS test
  holder. Generator `tools/abaptools/payment_model.py` (repository tools; `--check`, tests in `tools/tests`).
- Tables `ZCA_OPS_PMDIM` (dimension texts and display order) and `ZCA_OPS_FEEDER` (feeder systems, deep-link URL
  template, reference visibility), entities `PaymDimText` / `PaymFeeder` of `ZUI_CA_OPS_CFG`, CDS
  `ZI_CA_PaymDimText`, `ZI_CA_PaymFeeder`. Guide `docs/ADDING_A_CUSTOMER_PAYMENT_MODEL.md`; VERIFY V94-V99.
## [Unreleased] - 2026-11-11 (SAP job monitor)

Goal: every job failure of the client on the board - also a child job that failed while the job an external scheduler
started ended *finished* - tracked, linked to its parent and root and traceable to the most granular evidence.

### Added
- SAP job monitor (`docs/JOB_MONITORING.md`): registered checks `ZCL_CA_OPS_CHK_JOB_FAIL` (incremental after a
  watermark with overlap and caps: `JOB_ABORTED`, `JOB_LOG_ERROR`, `JOB_CHILD_FAILED` when the root did not abort) and
  `ZCL_CA_OPS_CHK_JOB_STATE` (`JOB_LONG_RUNNING`, `JOB_NOT_STARTED`); engine `ZCL_CA_OPS_JOB_MONITOR`, data access
  `ZIF_CA_OPS_JOB_DAO` / `ZCL_CA_OPS_JOB_DAO` (TBTCO, TBTCP, BALHDR read only), job log seam `ZIF_CA_OPS_JOB_LOG` /
  `ZCL_CA_OPS_JOB_LOG` (BP_JOBLOG_READ, TEST-SEAM) with budget `ZCL_CA_OPS_JOB_LOG_CACHE`, time points
  `ZCL_CA_OPS_JOB_TIME`, types `ZIF_CA_OPS_JOB_TYPES`.
- Parent / child resolvers `ZIF_CA_OPS_JOB_RESOLVER` with evidence quality (C confirmed, P probable): FIELD (TBTCO
  fields checked by RTTI, off), EVENT (start after job), JOBLOG (announcing message, off), HEURISTIC (scheduling user
  and run time, unique candidate only); recursive to `JOB_MAX_DEPTH`. Plug-ins for a consumer's business context
  (`ZIF_CA_OPS_JOB_ENRICHER`) and for de-duplication with another monitor (`ZIF_CA_OPS_JOB_CLAIM`).
- Evidence tables `ZCA_OPS_JOB`, `_JOBSTEP`, `_JOBMSG`, `_JOBALOG`, `_JOBBO`, watermark `ZCA_OPS_JOBWM`, external
  scheduler mapping `ZCA_OPS_JOBSCH` (entity *Scheduler jobs* of `ZUI_CA_OPS_CFG`), purge target class
  `ZCL_CA_OPS_JOB_PURGE` (`RETENTION_DAYS_JOB_EVIDENCE`).
- Board `ZUI_CA_OPS_JOBS` (read only): `ZR_CA_OpsJobFailure` / `ZC_CA_OpsJobFailure` with facet views, DCL
  `ZC_CA_OPSJOBFAILURE`, overview card counters; CDS tests `ZCL_CA_OPS_JOB_CDS_TEST`.
- Parameters `JOB_*` (prefix `JOB_` read in area `CA_OPS`), messages 110-129, VERIFY V58-V66.
## [Unreleased] - 2026-11-11 (operations response features)

Goal: the right person learns about a problem once, at the right time, with the first step in hand, and the
response time is measured. Reusable by any consumer: configuration of its areas only. `docs/OPERATIONS_FEATURES.md`.

### Added
- **Runbook link per check**: table `ZCA_OPS_RUNBOOK` (area, finding field `RULE_ID` / `CHECK_CODE` / `GROUP2`, exact
  value, link, one-line first action, active) in `ZUI_CA_OPS_CFG` (an active row needs an http(s) link, 439); CDS
  `ZI_CA_OpsFindRunbook` (CHECK_CODE before GROUP2 before RULE_ID) for the exceptions app (link column, facet
  *Runbook*) and any app; alert e-mail keys `RUNBOOK_URL` / `FIRST_ACTION` (`ZCL_CA_OPS_ALERT_POLICY=>RUNBOOK_FOR`,
  built-in layout, generic template, `ZI_CA_OPS_ALERTMAILCTX`).
- **Planned downtime windows**: table `ZCA_OPS_DTWIN` (area, PCRE scope on check code / object key / interface or bank,
  local start and end in the window's stored time zone `DOWNTIME_TIME_ZONE` and the UTC pair, reason, planner,
  approver); app `ZUI_CA_OPS_DTW` (`ZR_CA_OpsDowntime`, no draft, status derived - a window ends by itself; four-eyes
  approval with ZCA_OPS 85, never the planner; *End now*; checks on save: order, `DOWNTIME_MAX_HOURS`,
  `DOWNTIME_PAST_TOL_MIN`, reason, patterns, no overlapping window of the same scope); `ZCL_CA_OPS_DOWNTIME_POLICY`;
  API `ZIF_CA_OPS_DOWNTIME` / `ZCL_CA_OPS_DOWNTIME` (`WINDOWS`, `PLANNED` - "is this planned?" for missing-volume and
  SLA checks -, `AREA_PLANNED`; factory `GET_DOWNTIME`, injector `INJECT_DOWNTIME`). Findings inside an approved
  window are recorded with `ZCA_OPS_FINDING-DOWNTIME_ID`; the router holds back their alerts and logs status **D**
  (140; run-level alerts inside an area-wide window, 157); marks on the exceptions app, the daily control review
  (`DowntimeFindings`, `IsPlannedDowntime`, `DowntimeCount`) and the area dashboard (`IsPlannedDowntime`,
  `ZI_CA_OpsDtwNow`, `ZI_CA_OpsDtwActive`); built-in purge target `DOWNTIME` (`DOWNTIME_RETENTION_DAYS`).
- **Escalation until acknowledged**: rule fields `ESC_AFTER_MIN`, `ESC_REPEAT_MIN`, `ESC_MAX_COUNT`, `ESC_SEVERITY`
  (`ZCA_OPS_ALRULE`, app regenerated), parameter `ESC_MAX_DEFAULT`; `ZIF_CA_OPS_ALERT=>ESCALATE` (DEFAULT IGNORE) and
  report `ZCA_OPS_ESCALATE` (ZCA_OPS 16): an open, unassigned exception is escalated to the rule's escalation list
  after X minutes, every Y minutes up to the limit, until assigned, waived or resolved; one intent per exception and
  step (unique index INT), every attempt logged with `ZCA_OPS_ALLOG-ESC_STEP` / `-FINDING_NO` (156). Precedence: a
  rule with `ESC_AFTER_MIN` escalates by time only; the run-based `ESCALATE_AFTER` is unchanged for the others; the
  throttle and the run-based series ignore escalation, D and K rows.
- **Alert correlation**: table `ZCA_OPS_CORR` (check-code pattern, key fields, key pattern with one capture group,
  window in minutes) in `ZUI_CA_OPS_CFG` (153 / 154); `ZCL_CA_OPS_CORRELATOR` applied by the store to new open
  exceptions - the first of a key in the window is the parent, later ones its children (`ZCA_OPS_FINDING-CORR_ID`,
  `-CORR_ROLE`, `-CORR_KEY`, indexes `COR` / `CRI`; a correlation ID, not a pointer to the parent's row, so the
  carry-forward keeps the link; the company code is part of every key). The router sends one alert per parent with
  the number of open children (`CORRELATED_COUNT`) and logs held-back children with status **K** (141); exceptions
  app facets *Correlated exceptions* / *Parent exception* (`ZI_CA_OpsCorrCount`). No separate bulk action: the
  existing *Resolve* works on several selected children.
- **Response-time metrics (MTTA / MTTR)**: CDS `ZI_CA_OpsExcEpisode`, `ZI_CA_OpsExcAssign1`, `ZI_CA_OpsExcReopen`,
  `ZI_CA_OpsExcTimes`, `ZR_CA_OpsExcMetric` / `ZC_CA_OpsExcMetric` (per area, team, check, severity, company code,
  month / week in `METRIC_TIME_ZONE`: raised, assigned, resolved, open, re-opened, average minutes to assign /
  resolve, time buckets instead of percentiles, open by age), DCL, analytical list page service `ZUI_CA_OPS_MET`,
  card data points; team = owner team of the controls that cover the check (`ZI_CA_OpsCheckTeam`, `ZI_CA_OpsFindTeam`).
- **Shift handover**: shift starts per team from `SHIFT_TIMES_<team>` / `SHIFT_TIMES_DEFAULT` (kind S, TIME) in
  `SHIFT_TIME_ZONE`; CDS `ZI_CA_OpsShiftDef` ... `ZI_CA_OpsShiftWin`, `ZI_CA_OpsHovrEvt`, `ZI_CA_OpsHovrSum`,
  `ZR_CA_OpsHandover` / `ZC_CA_OpsHandover` (since the start of the previous shift per team, area and company code:
  new, resolved, still open, escalated, controls awaiting sign-off, planned downtime active / next shift), DCL, list
  report service `ZUI_CA_OPS_HOVR`, card data points. No handover note table (decision: a team note cannot be
  protected by the area / company-code rule).
- Types `ZIF_CA_OPS_RESP_TYPES`; name prefixes `RUNBOOK_`, `DOWNTIME_`, `ESC_`, `CORR_`, `METRIC_`, `SHIFT_` read in
  area `CA_OPS`; 9 parameter definitions (47 in all with the SAP job monitor); messages 140-160; domain `ZCA_OPS_DTW_STATUS`; alert DAO
  `GET_MARKS`, `GET_CHILD_COUNTS`, `GET_RUNBOOKS`, `GET_ESCALATION_CANDIDATES`, `GET_INTENT_LOG` (DEFAULT IGNORE);
  configuration checks `LINK_VALID`, `KEY_FIELDS_VALID`, `WINDOW_MIN_VALID`.
- Tests: downtime policy (14) and API (4, OSQL), correlator (9), router (`ltc_response`, 9), policy (`ltc_response`,
  9), store (3), purge DAO, configuration checks, factory; CDS tests `ZCL_CA_OPS_MET_CDS_TEST`,
  `ZCL_CA_OPS_HOVR_CDS_TEST`. VERIFY V70-V79.

### Changed
- `ZCL_CA_OPS_PURGE` test `deletes_in_packages`: one commit per built-in target - the expectation (4) had not counted
  REVIEW; with DOWNTIME it is 6.
- Generic template `ZCA_OPS_ALERT_DEFAULT` (documented source): four rows for the new context keys.
- Coding standards review of the build: new test method bodies wrapped in `TRY ... CATCH cx_root`, test rows of the
  handover CDS test built field by field; downtime validations clear and tag their state areas (`VALIDATE_AREA`,
  `VALIDATE_WINDOW`); an escalation step without intent key is logged failed (message 160) instead of being sent
  without its duplicate guard; concurrency, side-effects and analytics notes in `docs/OPERATIONS_FEATURES.md` §6a.

### Offline evidence (2026-11-11)
- abaplint 0 issues, `tools/checks.py` 17/17, serializer / parameter seed / configuration app up to date, tool tests
  green; the suite lints clean against the changed framework. Not proven offline: `docs/VERIFY.md` V70-V79.

## [Unreleased] - 2026-11-10 (process onboarding)

Goal (user, 2026-11-10): a new business process is added and integrated end to end - from Fiori to backend -
mostly by configuration plus at most one small check class.

### Added
- Overview cards of the area dashboard (2026-11-10): counters `CheckCount` (one per registered check, area-level
  slice only), `StaleCount` and flag `IsAttention` (open exception or stale) on `ZR_CA_OpsCheckStatus` /
  `ZC_CA_OpsCheckStatus` (summed by default), data points `ProcessChecks`, `ChecksFlagged`, `ChecksStale` and the
  `Attention` / `Stale` variants in its metadata extension, so a consumer's overview page shows KPI card *Business
  processes* and list card *Process checks - attention* by exposing the projection; CDS tests
  `ZCL_CA_OPS_DASH_CDS_TEST` (VERIFY V57).
- Check contract `ZIF_CA_OPS_CHECK` and the generic runner `ZCL_CA_OPS_CHECK_RUNNER` / report `ZCA_OPS_CHECK_RUN`:
  one run per area and schedule group (run variant) with authorisation 16, run lock, run header durable first,
  every active check of the registry `ZCA_OPS_CHECK` (class by name, interface checked first), GROUP1 = process
  and GROUP2 = check stamped on every finding, a check that raises = `CHECK_FAILED` and the run continues,
  auto-resolve of complete checks only (reconcile by GROUP2), alert rules after the commit (`ALERT_FAILED`
  when the dispatch raises), abort through `ZCL_CA_OPS_RUN_GUARD`.
- Process register `ZCA_OPS_PROC` (area, process, owner, backup, runbook, role, own tables, purge target).
- No-code aggregate check `ZCL_CA_OPS_CHK_AGG`: rows of `ZCA_OPS_AGG` over tables approved per area in
  `ZCA_OPS_TABWL` - COUNT of the rows in a status or AGE of the oldest, one database aggregate per row, grouped by
  the company-code field (findings carry BUKRS), amber / red limits; builder `ZCL_CA_OPS_AGG_QUERY` (DDIC-checked
  names, quoted literals, fixed operators), S_TABU_NAM 03 per table. The framework's equivalent of the first
  consumer's generic aggregate (which keeps its richer metric version).
- Onboarding check `ZCL_CA_OPS_CHK_ONBOARD` (registry row `CA_OPS` / `ONBOARDING`, schedule group `MORNING`,
  delivered inactive): a registered process without an active check, a control covering each check, an alert
  rule of its area, an owner who is a user, a purge target for own tables, a role and an active area.
- Area dashboard `ZUI_CA_OPS_DASH` (`ZR_CA_OpsCheckStatus`, `ZC_CA_OpsCheckStatus`, DCL `ZC_CA_OPSCHECKSTATUS`):
  per area, check and company-code slice the last run, status, open exceptions and freshness (parameters
  `CHECK_STALE_MIN_<area>`, `CHECK_STALE_MIN_DEFAULT` = 1500 minutes; prefix `CHECK_` read in `CA_OPS`).
- The four tables in `ZUI_CA_OPS_CFG` (generated; table and field checks of aggregate rows, messages 082 / 083).
- `ZIF_CA_OPS_CHECK_DAO` / `ZCL_CA_OPS_CHECK_DAO`, `ZIF_CA_OPS_CHK_TYPES`; factory `GET_CHECK_DAO`, injector
  `INJECT_CHECK_DAO`; messages 082-103; seed files `config/process_register.csv`, `check_registry.csv`,
  `check_aggregates.csv`, `approved_tables.csv`.
- Offline: check `process_onboarding` of `tools/checks.py` (shared engine `../tools/abaptools/onboarding.py`),
  scaffold `../tools/abaptools/new_process.py`; guide `docs/ADDING_A_BUSINESS_PROCESS.md`; VERIFY V46-V54.

## [Unreleased] - 2026-11-10 (company-code isolation)

An external review found that a user restricted to one company code could see findings, history and counts
of another company code (findings had no company code; the DCLs filtered by area only).

### Added
- `ZCA_OPS_FINDING-BUKRS` (company code of the finding, blank = not company-specific), stored by the store
  from `TY_FINDING-COMPANY_CODE`; part of the identity of an exception in the carry-forward.
- Read rule of the DCLs: area authorised AND ( company code blank OR ( area, company code ) authorised ) on
  the exceptions app, its history (path to the exception) and the daily control review.
- Daily control review per company-code slice: `ZI_CA_OpsCtlSlice`; key `BUKRS` of `ZCA_OPS_REVIEW` and of
  `ZR_CA_OpsCtlReview` / `ZC_CA_OpsCtlReview`; status, findings, open exceptions and sign-off per slice.
- Write rule: `ZCL_CA_OPS_EXC_POLICY=>MAY_ACT` in the instance authorisation of the exceptions app and the
  review app (company code of the object).
- Alert rule pattern `BUKRS_PATTERN` (`ZCA_OPS_ALRULE`, app `ZUI_CA_OPS_CFG`, checked on save).
- Tests: isolation policy, store, alert policy, review DAO, control CDS slices, DCL holder
  `ZCL_CA_OPS_DCL_TEST` (access-control double). `docs/auth_zca_ops.md` §3c; VERIFY V35-V43.

### Changed
- `ZIF_CA_OPS_REVIEW_DAO=>LOCK` takes the company code of the slice (lock argument with `BUKRS`).
- Retention target REVIEW deletes by the full key including `BUKRS`.

## [Unreleased] - 2026-11-10 (pilot review: alert audit log)

- Fixed: routing decisions (throttled, quiet hours, repeat, failed by `SEND`) were written with a blank
  intent key and attempt 0; with the unique index `INT` (MANDT, INTENT_KEY, ATTEMPT) every decision after
  the first collided and `INSERT ... ACCEPTING DUPLICATE KEYS` dropped it without a trace. Such a row now
  carries its alert ID (hex) as intent key; a row the database refuses raises message 081 (the run records
  `ALERT_FAILED`); the fallback insert of `COMPLETE` is checked. `INSERT_LOG` and `COMPLETE` declare
  `ZCX_CA_OPS_ERROR`. Verification in DV1: `docs/VERIFY.md` V34.

## [Unreleased] - 2026-11-10 (control register and daily control review)

User decisions 2026-11-10: a daily sign-off per control and business date (who, when, observation); no
incidents in SAP; statuses derived from the source, never copied; configuration by transport.

### Added
- Control register `ZCA_OPS_CONTROL` (owner, backup, team, review cut-off, runbook link, sequence),
  `ZCA_OPS_CTLT` (guidance per language), `ZCA_OPS_CTLCHK` (checks a control covers: area of the findings,
  `RULE_ID` / `CHECK_CODE` / `GROUP2`, exact value) in the generated app `ZUI_CA_OPS_CFG`; checks on save:
  owner / backup user (437, `ZIF_CA_OPS_AUTH=>USER_EXISTS`), team (438, `CONTROL_TEAMS`), runbook link (439).
- Daily control review: sign-off table `ZCA_OPS_REVIEW`; status per business date derived in CDS from the live
  findings of the date (B / E action required, W watch), awaiting and overdue review; RAP BO
  `ZR_CA_OpsCtlReview` with action *Mark reviewed* (lock + ETag), DCL by area, service `ZUI_CA_OPS_REV`;
  `ZCL_CA_OPS_REVIEW_POLICY`, `ZIF_CA_OPS_REVIEW_DAO` / `ZCL_CA_OPS_REVIEW_DAO` (factory / injector slot),
  `ZIF_CA_OPS_CTL_TYPES`, domain `ZCA_OPS_CTL_STATUS` (translatable status texts); messages 076-080;
  `docs/CONTROL_REVIEW.md`.
- Exceptions app: action *Classify* (reason code of an open exception, `ZCA_OPS_FINDING-REASON_CODE`, history
  action CLASSIFY, message 068), carried forward by the store.
- Built-in purge target `REVIEW`; parameters `CONTROL_TIME_ZONE`, `CONTROL_TEAMS`, `EXC_REASON_CODES`,
  `RETENTION_DAYS_REVIEW` (area `CA_OPS`, 15 definitions); name prefixes `CONTROL_` / `EXC_` read in `CA_OPS`.
- Tests: review policy, review DAO (OSQL), control CDS (`ZCL_CA_OPS_CTL_CDS_TEST`), control field checks,
  classification policy, review purge.

## [Unreleased] - 2026-11-10 (alert e-mail templates)

User decisions 2026-11-10: every alert e-mail is an editable template (SAP e-mail templates, object type
SMTG), templates change in DV1 and move by transport only, whether alerts show amounts is configuration
(default off). Release constant unchanged (`GC_VERSION` 1.0.0) until the release is cut.

### Added
- Renderer port `ZIF_CA_OPS_MAIL_TEMPLATE`; SAP e-mail template adapter `ZCL_CA_OPS_MAIL_TPL_SMTG` (the only
  caller of `CL_SMTG_EMAIL_API`, dynamic calls, test seams, VERIFY-ADT); built-in layout
  `ZCL_CA_OPS_MAIL_TPL_BUILTIN` (fallback, same content); composer `ZCL_CA_OPS_MAIL_COMPOSER` (template order
  rule > section > channel > generic, plain tokens for table blocks, tables put in after rendering, a
  template without placeholder gets the table appended and the log records it); factory slot
  `GET_MAIL_TEMPLATE` / `INJECT_MAIL_TEMPLATE`.
- Standard business-context keys of the alert e-mail (`ZIF_CA_OPS_TYPES=>TY_MAIL_HEADER`), table blocks
  `TABLE_MAIN` / `TABLE_SECTION`; business context of a finding (`TY_FINDING`: business date, company code,
  account label, payment method, count; not stored); exception facts of a run (`GET_EXCEPTION_FACTS`: new /
  repeated / overdue, due date, owner).
- Fields `ZCA_OPS_ALRULE-TEMPLATE_ID` / `-SHOW_AMOUNTS`, `ZCA_OPS_ALCHN-TEMPLATE_ID`, `ZCA_OPS_ALLOG-TEMPLATE_ID`
  / `-RENDERER` / `-RENDER_INFO`; configuration app regenerated (check on save, message 436).
- CDS data source `ZI_CA_OPS_ALERTMAILCTX`; generic template `ZCA_OPS_ALERT_DEFAULT` as a documented source
  (`templates/zca_ops_alert_default.md`); `docs/ALERT_TEMPLATES.md`.
- Parameters `ALERT_MAIL_RENDERER`, `ALERT_TEMPLATE_DEFAULT`, `ALERT_TIME_ZONE`, `ALERT_EXC_APP_LINK` (area
  `CA_OPS`, 11 definitions); messages 070-075, 436.
- `SEND( )`: optional template around a prepared report.
- Section plug-in: optional method `TEMPLATE_ID` (DEFAULT IGNORE - existing sections unchanged).

### Changed
- Findings table of the alert e-mail: amounts only when the rule has `SHOW_AMOUNTS` (was always shown); a
  column is shown when a finding has a value; details lines shown. Digest subject impact first:
  `[SYSID][AREA][severity] <check or rule>: <n> finding(s)` (message 003 reworded; 074 with amounts).
- The router renders e-mail messages after the claim; the claim keeps the code's subject and intent key.

### Offline evidence
- abaplint 0 issues, `tools/checks.py` 16/16, generators up to date. Not proven offline:
  `docs/VERIFY.md` V17-V25 (`docs/ALERT_TEMPLATES.md` section 8).

## [Unreleased] - 2026-11-10 (customer kit)

Release constant unchanged (`GC_VERSION` 1.0.0): nothing of the framework's behaviour changed.

### Added
- Optional demo consumer, sub-package `ZCA_OPS_DEMO` (`src/demo`, not for production): report
  `ZCA_OPS_DEMO`, `ZCL_CA_OPS_DEMO`, `ZIF_CA_OPS_DEMO_DAO` / `ZCL_CA_OPS_DEMO_DAO`, `ZIF_CA_OPS_DEMO_TYPES`;
  one run of area `CA_DEMO` with job counts of the last 24 hours (`TBTCO`, read only): information, error
  (open exception) and warning findings, alert dispatch, test mode, sample mode; unit tests with local
  doubles and an OSQL double. Messages 900-903. Seed rows `config/demo/` (area, APPLOG channel, rule).
- `docs/INSTALL.md`: installing at a new customer (checklist with the `ZCA` name-clash look-up and reuse
  rights, pull order, SU21, roles, SLG0, SO23, parameters, purge job, first area, verification).
- README: consumer how-to with code (area, parameters, findings, alerts, alert section plug-in, purge
  target, errors, tests).
- Tooling: the engines are the repository's shared tools (`../tools/abaptools`, tests `../tools/tests`);
  `tools/` holds thin wrappers. The configuration app is generated from this folder
  (`tools/rap_generate.py`, was the first consumer's generator). Checks `method_names` and `packaging`
  (no file names a consumer's folder) added; PCRE / CP / name checks are the shared ones.

### Offline evidence (2026-11-10)
- abaplint 2.120.92 (`abaplint.json`): 0 issues; `tools/checks.py` 16/16; serializer, parameter seed and
  configuration app up to date; tool tests and shared tool tests green. Generated files byte-identical
  before and after the move of the engines. Not proven offline: `docs/VERIFY.md` V12-V16.

## [1.0.0] - 2026-11-10

First release (`ZIF_CA_OPS_TYPES=>GC_VERSION`), extracted from the operations suite of its first consumer
(`ops-suite/`), which consumes it. Needs ZCA_PARAM 1.1.0 or later (`GC_PARAM_MIN_VERSION`, checked
once per session by `ZCL_CA_OPS_FACTORY=>CHECK_VERSION` at `start_run`, message 044).

### Decisions (user, 2026-11-10)
- Prefix `ZCA` (no registered namespace); ZCA_PARAM and ZCA_OPS stay separate components shipped together.
- One area register: the area of a run, finding, alert rule, lock, purge target and configuration app
  is a parameter area of ZCA_PARAM (`ZCA_PARAM_AREA`, data element `ZCA_PARAM_AREA_ID`, CHAR 16);
  `start_run` refuses an unknown or inactive area (043).
- One authorisation object: `ZCA_OPS` in object class `ZCA` (fields `ZCA_PARAR`, `ACTVT`, `BUKRS`),
  replacing the first consumer's own authorisation object and area check.

### Added
- Store, exception lifecycle and exceptions app (`ZUI_CA_OPS_EXC`), alert router / policy / DAO /
  channels, run lock and run guard, configuration gate and field checks, retention purge, utilities,
  parameters adapter, factory / injector - moved from the suite with `ZCA_OPS` / `ZCL_CA_OPS_*` /
  `ZIF_CA_OPS_*` names (modification logs kept, line "Moved from ..." added).
- `ZIF_CA_OPS_ALERT_SECTION`: a consumer's own table in the alert message (parameter
  `ALERT_SECTION_CLASS`); before, the policy called the suite's bank ACK table directly.
- `ZIF_CA_OPS_PURGE_TARGET` and registry `ZCA_OPS_PURGE` (target, class, retention parameter; checked on
  save): consumers register their purge targets; the framework purges RUN and ALERT_LOG itself.
- `ZCX_CA_OPS_ERROR=>CLASSIFY`: a consumer's subclass classifies its own messages (TRANSIENT / CONFIG).
- `ZIF_CA_OPS_PARAMS`: optional area per read, `ADD_PREFIXES`, `AREA_OF`, `CHECK_AREA`.
- Message class `ZCA_OPS` (58 messages; numbers of moved messages kept, new 043, 044, 434, 435).
- Parameters of area `CA_OPS` (7 definitions, `config/param_definitions.csv`, `docs/PARAMETERS.md`).
- Configuration app `ZUI_CA_OPS_CFG` (alert rules, alert channels, purge targets), generated by
  `ops-suite/tools/rap_generate.py`.
- Tooling: abapGit serializer (programs and text pools added to the parameter framework's), house
  checks (layering, customer wording, messages, test paths, parameter seed), parameter seed generator
  (configurable, shared with the suite), CI workflow, tool tests.

### Offline evidence (2026-11-10)
- abaplint 2.120.92 (`abaplint.json`, v758, ZCA_PARAM as dependency): 0 issues.
- `tools/checks.py` 14/14, serializer and parameter seed up to date, tool tests green.
- Not proven offline: activation, DDIC, RAP runtime, ABAP Unit, ATC (`docs/VERIFY.md`).

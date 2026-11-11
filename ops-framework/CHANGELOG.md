# Changelog

All notable changes of the operations framework (`ops-framework/` in jaideep247/bai).

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

First release (`ZIF_CA_OPS_TYPES=>GC_VERSION`), extracted from the payment engine operations suite
(`ops-suite/`), which consumes it. Needs ZCA_PARAM 1.1.0 or later (`GC_PARAM_MIN_VERSION`, checked
once per session by `ZCL_CA_OPS_FACTORY=>CHECK_VERSION` at `start_run`, message 044).

### Decisions (user, 2026-11-10)
- Prefix `ZCA` (no registered namespace); ZCA_PARAM and ZCA_OPS stay separate components shipped together.
- One area register: the area of a run, finding, alert rule, lock, purge target and configuration app
  is a parameter area of ZCA_PARAM (`ZCA_PARAM_AREA`, data element `ZCA_PARAM_AREA_ID`, CHAR 16);
  `start_run` refuses an unknown or inactive area (043).
- One authorisation object: `ZCA_OPS` in object class `ZCA` (fields `ZCA_PARAR`, `ACTVT`, `BUKRS`),
  replacing the suite's `ZCD_OPS` / `ZCD_PE_AREA`.

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

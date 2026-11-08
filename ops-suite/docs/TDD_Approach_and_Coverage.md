# TDD approach and coverage — Operations Suite

> **First principle:** if something is hard to test, it is in the wrong layer.
> **Analogy:** a recipe is tasted at every step, not only when the dish is served.

## 1. Why the architecture is shaped this way

- **Domain classes hold no SQL and call no function payment engine areas.** Rules (`ZCL_CD_EBS_R_*`), resolvers, policies (`ZCL_CD_OPS_ALERT_POLICY`), status machines (`ZCL_CD_FMON_STATUS`), evaluation rules (`ZCL_CD_FMON_RULES`, `ZCL_CD_HCK_CYCLE_EVAL`), statistics and renderers work on structures. Tests build them field by field and assert the result.
- **Everything touching the outside world is behind an interface** — store, alert router, alert DAO, channels, clock, EBS/FMON/HCK repositories, parsers, sources, calendar, DDIC describer. Engines get them from the factories, so tests inject `LTD_*` doubles and assert what the engine *did*.
- **Plug-ins are registry rows, not a `CASE`.** A new rule, check, adapter or channel is a new class plus a customizing row, so its test is new too — no existing test changes.

## 2. The loop

**Red** — write the failing test in the class that owns the behaviour, named after the rule (`unmapped_btc_always_blocks`, `partial_returns_stay_partial`, `stuck_step_after_max_runtime`). **Green** — make it pass in the smallest correct place. **Refactor** — move shared logic into the base/helper classes with the tests as the safety net. **Parity** — any behaviour change against the legacy validators gets a row in `Legacy_Parity_Comparison.md` in the same change.

### How strictly the loop was followed in this build (honest record)

| Order | Objects | Evidence |
|---|---|---|
| **Test first** — test include written before the class; lint failed ("class/method not found") until the class existed | `ZCL_CD_EBS_BTC_RESOLVER`, `ZCL_CD_OPS_ALERT_POLICY`, `ZCL_CD_OPS_ALERT_ROUTER`, the 28 `ZCL_CD_EBS_R_*` rules (via `ZCL_CD_EBS_RULE_BASE` test include), `ZCL_CD_EBS_ENGINE`, `ZCL_CD_EBS_SRC_FEB`, `ZCL_CD_EBS_PE_SCOPE` and the payment engine scope tests of the engine and the dashboard (2026-11-06) | Red state observed by the lead developer in the lint output |
| **Test first — reported, not independently verifiable** | `ZCL_CD_EBS_PARSER_BAI2`, `ZCL_CD_EBS_PARSER_CAMT`, all FMON and HCK classes with test includes | Stated in the hand-over reports of the developers who built them; no file history records the order |
| **Test after** (characterisation tests, written once the class existed) | `ZCL_CD_OPS_UTIL`, `ZCL_CD_OPS_STORE`, `ZCL_CD_EBS_CFG_DAO`, `ZCL_CD_EBS_FEB_DAO`, `ZCL_CD_EBS_SAP_DAO` (written before the TDD approach was adopted for this build); `ZCL_CD_EBS_FINDING`, `ZCL_CD_OPS_FACTORY` (plug-in creation), `ZCL_CD_EBS_SRC_FILE` (gap closure, 2026-11-06) | Modification log of each test include |
| **Test first, audit fixes 2026-11-06** — test written before the fix, fix written after; not executed (no ABAP Unit offline) | `ZCL_CD_FMON_ENGINE` (`alerts_sent_after_commit`, `persist_error_rolls_back`), `ZCL_CD_HCK_ENGINE` (`alerts_sent_after_commit`) | `history/Audit_History.md` §1 (B-P0 … B-P2) |
| **Test after, file monitoring dashboard 2026-11-06** — CDS tests written against the drafted views (bucket table and SLA rule first in the doc, then views, then `cl_cds_test_environment` tests); not executed | `ZCL_CD_FMON_FLOW_CDS_TEST` (19: `ltc_flow` 12, `ltc_as_of` 5, `ltc_kpi` 2) | `Dashboard_File_Monitoring.md` §11 |
| **Test first, payment trace 2026-11-06** — engine tests written against the draft before the review fixes (partner mismatch, history unavailable on reversal, cheque history unavailable, digest file reference); lint red until the code existed; not executed | `ZCL_CD_OPS_TRACE_ENGINE` (21), `ZCL_CD_OPS_TRACE_DAO` (8) | `Payment_Trace.md` §10 |
| **Test first, core controls 2026-11-06** — test written before the code it drives; lint red until the code existed; not executed | `ZCL_CD_OPS_RUN_GUARD`, `ZCL_CD_OPS_PURGE`, `ZCL_CD_OPS_PURGE_DAO`, store carry-forward / `reconcile` (7 OSQL tests), engine lock and reconciliation tests (EBS 4, FMON 4, HCK 3), `injected_auth_is_returned` | `RAP_Apps_Design.md` §1–§4; commit history of 2026-11-06 |
| **Test first, configuration apps** — red observed in abaplint (47 "not found") before the classes existed | `ZCL_CD_OPS_CFG_POLICY`, `ZCL_CD_OPS_CFG_CHECKS`, `ZCL_CD_OPS_CFG_GATE` | Phase 2 hand-over |
| **Test first, EBS rule audit** (part C) | 7 rule tests (`r07_any_run_with_status_ok` … `r18_unmapped_gl_reported`) written before the fixes | `history/Audit_History.md` §1 (C) |
| **Test first, operations apps** (phase 3) — tests written before each class / engine change; not executed | `ZCL_CD_OPS_EXC_POLICY`, `ZCL_CD_OPS_EXC_DAO`, `ZCL_CD_HCK_SUPPRESSION`, `ZCL_CD_HCK_PAYREQ_RULES`, `ZCL_CD_HCK_VALUE_QUERY`, `ZCL_CD_FMON_OPS_POLICY`, `ZCL_CD_FMON_STATUS=>MANUAL_ALLOWED`; engine tests for suppression; store `pending_waiver_is_carried` | `RAP_Ops_Apps.md` §3 |
| **Test after (characterisation)**, phase 3 | `success_wins_over_later_fail`, `success_after_fail_wins` (existing state-machine behaviour, pinned for the PRISM SUCCESS rule) | `RAP_Ops_Apps.md` §3 |
| **Test first, phase 5** (no hardcoding, R21) | `text_fills_message_vars`, `text_tail_is_not_truncated` (ZCL_CD_OPS_UTIL), `r21_missing_record_reported`, `r21_any_allowed_status_ok`, `r21_status_not_allowed`, `r21_unknown_lookup_raises`, `bai143_collections_only`, `bai452_validated_as_468`, `sweep_275_575_not_validated` | Written before the helper / rule / map rows; texts moved without behaviour change (existing assertions kept, FMON lot test asserts message number and variables) |
| **No unit test by design** | See §5 | Covered by the listed alternative |

**What "red" and "green" mean here.** In this build red was a test that did not compile against missing code and green was a clean abaplint run. That proves each test targets the new code; it does **not** prove the tests pass. True red/green — an assertion failing, then passing — happens at the first ABAP Unit run in DV1. Until then no test result exists.

## 3. Test levels

| Level | Runs | Covers | Isolation | Cost |
|---|---|---|---|---|
| Domain | always | rules, resolvers, policies, statistics, renderers, parsers | none | free |
| Application | always | engines: orchestration, persistence calls, alerts, circuit breaker, test mode | `LTD_*` doubles via injectors | free |
| OSQL | always | repository SQL: filters, keys, ordering, idempotency, empty-key guards | `cl_osql_test_environment` | cheap |
| Integration | QA1 only | wrappers over SAP standard (BCS, BAL, HTTP, factory calendar, RTTI, TBTCO/BALHDR/SNAP/VBHDR reads, dynamic SQL on legacy tables) | `RISK LEVEL DANGEROUS`, TVARVC-gated, functional test cases | manual |

## 4. Coverage today — 1126 ABAP Unit methods; 150 classes: 103 with an own test include, 46 covered by another include, 1 exempt

Every class of `src/` has one row in `Coverage_Run_Register.csv` (columns: test path, covering include, methods, required / measured coverage, status). `tools/portable_checks.py` regenerates the register from the test includes and from `tools/test_path_register.csv` (covering include or exemption, each with its reason), and refuses a class without either (check `test_path_every_class`). Coverage itself is measured only in DV1 (ABAP Unit with coverage, 90 % statement coverage per class) and recorded in the register.

Checks that keep the tests away from the real database (all portable, `tools/test_checks.py`, fixture tests `tools/tests/test_test_checks.py`):

| Check | Rule | Limits (static, best effort) |
|---|---|---|
| `test_path_every_class` | Own test include, or a register row naming a covering include that mentions the class, or an exemption with reason; stale rows fail | — |
| `osql_doubles_complete` | A test include of a class with Open SQL creates `cl_osql_test_environment` / `cl_cds_test_environment`, and every table read or written by the methods its tests call (and the private helpers they call) is in a double list | Dynamic names (`FROM (lv_table)`) not resolved; SQL inside an injected TEST-SEAM is excluded; a table a test never reaches is declared with `" osql-not-reached: <TABLE>` |
| `no_real_dao_in_tests` | A test include of a class without SQL injects doubles (`ZCL_CD_*_INJECTOR=>INJECT_*`) when the class gets a DAO / the store from a factory, and never creates a real DAO / store | Methods reached through another class are not followed |

### Parameters in tests — ZCA_PARAM (2026-11-07)

Parameters are `ZIF_CD_OPS_PARAMS` (`get_param`, `get_range`, `refresh_params`, `get_errors`), implemented only by the adapter `ZCL_CD_OPS_PARAMS_CA` over the global framework `ZCA_PARAM` (2026-11-07; the store no longer serves parameters, the fake `ZCL_CD_OPS_PARAMS_MEM` is removed). Tests run the **real framework logic** (`ZCL_CA_PARAM` — no second implementation of the semantics):

| Test level | Parameters in the test | Proves |
|---|---|---|
| Adapter `ZCL_CD_OPS_PARAMS_CA` | own definitions with `ZCL_CA_PARAM_BUILDER`, DAO injected with `ZCL_CA_PARAM_INJECTOR=>INJECT_DAO`, log channel double (`INJECT_PLUGIN`) | area by prefix, maintained value and definition default win over the caller default, BOOL blank row = off, caller default when nothing resolves, condensing, LIST / kind S as range, unknown name and invalid value logged once and listed, log failure does not stop, refresh = new snapshot |
| Delivered definitions `ZCL_CD_OPS_PARAM_SEED` | the generated definitions over `ZCL_CA_PARAM` | every delivered default is valid for its definition (type, limits, pattern, class + interface), every name maps to its area |
| Every class that reads parameters (engines, rules, DAOs, router, purge, store, trace, PRISM, HCK checks) | `NEW zcl_cd_ops_param_seed( )` (every delivered definition, in memory), `set( )` for a value row, `ZCL_CD_OPS_INJECTOR=>INJECT_PARAMS( ->params( ) )` | the class with the delivered definitions and defaults; store doubles serve no parameters |
| Configuration check `ZCL_CD_HCK_C_PARAM` | the seed's DAO injected into `ZCL_CA_PARAM_INJECTOR` and `ZCL_CD_HCK_INJECTOR=>INJECT_PARAM_DAO` | valid set, invalid value, invalid extra definition, missing definition, missing area |

Changed meaning, deliberately: a flag is switched off with a value row with blank value (`r08_zero_flag_off_rows_apart`, `registry_only_without_instant` — the open item of the blank `FMON_PRISM_INSTANT` is closed); a configured parser class without the parser interface is refused by the framework (`non_parser_value_not_used`), the factory's own RTTI check (A62) is proved with a reader double (`wrong_parser_class_refused`); the store's former parameter tests (blank, condensed, range) are adapter tests now; A64 (snapshot per run) is proved through `ZCL_CD_OPS_FACTORY=>GET_PARAMS`.

| Payment engine area | Object | Test path | Methods | Covering include / partial exemption |
|---|---|---|---|---|
| Core | ZBP_R_CD_OPSCFGALL | own test include | 4 | partial: global authorization tested (EML GET PERMISSIONS ONLY GLOBAL AUTHORIZATION - per activity 01 / 02 / 06 and none, root and first child, VERIFY-ADT); global features, validations and saver need GET PERMISSIONS FEATURES or draft EML with COMMIT ENTITIES, which the offline lint (abaplint 2.120.92) does not parse - DV1 cases RAP_Config_Apps.md 6; decisions tested in ZCL_CD_OPS_CFG_GATE / _CHECKS / _POLICY |
| Core | ZBP_R_CD_OPSEXCEPTION | exempt | 0 | Exempt: instance authorization / features and the four actions read persisted findings: EML with COMMIT ENTITIES on doubled ZCD_OPS_FINDING / ZCD_OPS_EXC_HIST, not parsed offline - QA1 OPS-01 .. OPS-08; every decision tested in ZCL_CD_OPS_EXC_POLICY |
| Core | ZCL_CD_OPS_ALERT_DAO | own test include | 7 |  |
| Core | ZCL_CD_OPS_ALERT_POLICY | own test include | 20 |  |
| Core | ZCL_CD_OPS_ALERT_ROUTER | own test include | 15 |  |
| Core | ZCL_CD_OPS_AUTH | own test include | 4 |  |
| Core | ZCL_CD_OPS_CFG_AUTH | own test include | 2 |  |
| Core | ZCL_CD_OPS_CFG_CHECKS | own test include | 38 | incl. ltc_posting_areas (16): every validation of the customer posting areas with ZCL_CD_OPS_POSTAREA_MEM |
| Core | ZCL_CD_OPS_CFG_CLIENT | own test include | 4 |  |
| Core | ZCL_CD_OPS_CFG_FACTORY | covered | 0 | ZCL_CD_OPS_CFG_GATE |
| Core | ZCL_CD_OPS_CFG_GATE | own test include | 9 |  |
| Core | ZCL_CD_OPS_CFG_INJECTOR | covered | 0 | ZCL_CD_OPS_CFG_GATE |
| Core | ZCL_CD_OPS_CFG_POLICY | own test include | 11 |  |
| Core | ZCL_CD_OPS_CFG_TRANSPORT | own test include | 2 |  |
| Core | ZCL_CD_OPS_CHN_APPLOG | own test include | 5 |  |
| Core | ZCL_CD_OPS_CHN_EMAIL | own test include | 4 |  |
| Core | ZCL_CD_OPS_CLOCK | own test include | 3 |  |
| Core | ZCL_CD_OPS_EXC_DAO | own test include | 2 |  |
| Core | ZCL_CD_OPS_EXC_POLICY | own test include | 9 |  |
| Core | ZCL_CD_OPS_FACTORY | own test include | 11 |  |
| Core | ZCL_CD_OPS_INJECTOR | covered | 0 | ZCL_CD_OPS_FACTORY |
| Core | ZCL_CD_OPS_LOCK | own test include | 4 |  |
| Core | ZCL_CD_OPS_OVW_CDS_TEST | own test include | 5 |  |
| Core | ZCL_CD_OPS_PARAMS_CA | own test include | 13 |  |
| Core | ZCL_CD_OPS_PARAM_SEED | own test include | 4 |  |
| HCK | ZCL_CD_HCK_C_PARAM | own test include | 5 |  |
| HCK | ZCL_CD_HCK_C_POSTAREA | own test include | 2 | findings and metric of D_POSTAREA_INVALID; validations in ZCL_CD_OPS_CFG_CHECKS |
| Core | ZCL_CD_OPS_PATTERN_CHECK | own test include | 19 |  |
| Core | ZCL_CD_OPS_PATTERN_DAO | own test include | 7 |  |
| Core | ZCL_CD_OPS_PLUGIN_PROBE | covered | 0 | ZCL_CD_OPS_FACTORY |
| Core | ZCL_CD_OPS_POSTAREA | own test include | 7 | FQC0 precedence (exact beats *, left-most exact key wins, no match), one read per area and run, parameters |
| Core | ZCL_CD_OPS_POSTAREA_DAO | own test include | 3 | OSQL, TFK033D doubled (VERIFY-DDIC) |
| Core | ZCL_CD_OPS_POSTAREA_FACTORY | covered | 0 | ZCL_CD_OPS_POSTAREA |
| Core | ZCL_CD_OPS_POSTAREA_INJECTOR | covered | 0 | ZCL_CD_OPS_POSTAREA |
| Core | ZCL_CD_OPS_POSTAREA_MEM | covered | 0 | ZCL_CD_OPS_POSTAREA |
| Core | ZCL_CD_OPS_PURGE | own test include | 5 |  |
| Core | ZCL_CD_OPS_PURGE_DAO | own test include | 8 |  |
| Core | ZCL_CD_OPS_RUN_GUARD | own test include | 4 |  |
| Core | ZCL_CD_OPS_STORE | own test include | 27 | partial: COMMIT / ROLLBACK (one statement each) - covered by the engine LUW tests with the store double |
| Core | ZCL_CD_OPS_TRACE_DAO | own test include | 14 | partial: reads delegated to the EBS SAP DAO and the FMON reader (cheques by number, configured reads, returns, retrievals) are tested in those classes |
| Core | ZCL_CD_OPS_TRACE_ENGINE | own test include | 28 |  |
| Core | ZCL_CD_OPS_UTIL | own test include | 22 |  |
| Core | ZCL_CD_TRX_DASH_CDS_TEST | own test include | 8 |  |
| Core | ZCX_CD_OPS_ERROR | covered | 0 | ZCL_CD_OPS_FACTORY |
| EBS | ZBP_R_CD_EBSCFGALL | own test include | 4 | partial: global authorization tested (EML GET PERMISSIONS ONLY GLOBAL AUTHORIZATION - per activity 01 / 02 / 06 and none, root and first child, VERIFY-ADT); global features, validations and saver need GET PERMISSIONS FEATURES or draft EML with COMMIT ENTITIES, which the offline lint (abaplint 2.120.92) does not parse - DV1 cases RAP_Config_Apps.md 6; decisions tested in ZCL_CD_OPS_CFG_GATE / _CHECKS / _POLICY |
| EBS | ZCL_CD_EBS_BTC_RESOLVER | own test include | 23 |  |
| EBS | ZCL_CD_EBS_CFG_DAO | own test include | 15 | BTC map from ZBTM, reasons from ZRSN (exact beats *) with ZCL_CD_OPS_POSTAREA_MEM |
| EBS | ZCL_CD_EBS_DASH_CDS_TEST | own test include | 22 |  |
| EBS | ZCL_CD_EBS_ENGINE | own test include | 43 |  |
| EBS | ZCL_CD_EBS_FACTORY | own test include | 4 |  |
| EBS | ZCL_CD_EBS_FEB_DAO | own test include | 9 |  |
| EBS | ZCL_CD_EBS_FINDING | own test include | 5 |  |
| EBS | ZCL_CD_EBS_INJECTOR | covered | 0 | ZCL_CD_EBS_FACTORY |
| EBS | ZCL_CD_EBS_PARSER_BAI2 | own test include | 27 |  |
| EBS | ZCL_CD_EBS_PARSER_CAMT | own test include | 24 |  |
| EBS | ZCL_CD_EBS_PE_SCOPE | own test include | 17 |  |
| EBS | ZCL_CD_EBS_RULE_BASE | own test include | 106 |  |
| EBS | ZCL_CD_EBS_R_R01_SIGN | covered | 0 | ZCL_CD_EBS_RULE_BASE |
| EBS | ZCL_CD_EBS_R_R02_BOUNDS | covered | 0 | ZCL_CD_EBS_RULE_BASE |
| EBS | ZCL_CD_EBS_R_R03_CURRENCY | covered | 0 | ZCL_CD_EBS_RULE_BASE |
| EBS | ZCL_CD_EBS_R_R04_REFERENCE | covered | 0 | ZCL_CD_EBS_RULE_BASE |
| EBS | ZCL_CD_EBS_R_R05_REASON | covered | 0 | ZCL_CD_EBS_RULE_BASE |
| EBS | ZCL_CD_EBS_R_R07C_CHECK | covered | 0 | ZCL_CD_EBS_RULE_BASE |
| EBS | ZCL_CD_EBS_R_R07L_RETRIEVAL | covered | 0 | ZCL_CD_EBS_RULE_BASE |
| EBS | ZCL_CD_EBS_R_R07R_RETURN_LOT | covered | 0 | ZCL_CD_EBS_RULE_BASE |
| EBS | ZCL_CD_EBS_R_R07_PAYMENT | covered | 0 | ZCL_CD_EBS_RULE_BASE |
| EBS | ZCL_CD_EBS_R_R08_CHECK_AMOUNT | covered | 0 | ZCL_CD_EBS_RULE_BASE |
| EBS | ZCL_CD_EBS_R_R09_DUPLICATE | covered | 0 | ZCL_CD_EBS_RULE_BASE |
| EBS | ZCL_CD_EBS_R_R10_VALUE_DATE | covered | 0 | ZCL_CD_EBS_RULE_BASE |
| EBS | ZCL_CD_EBS_R_R12_CODE_TOTAL | covered | 0 | ZCL_CD_EBS_RULE_BASE |
| EBS | ZCL_CD_EBS_R_R15_POSTING_RULE | covered | 0 | ZCL_CD_EBS_RULE_BASE |
| EBS | ZCL_CD_EBS_R_R18_GL_BALANCE | covered | 0 | ZCL_CD_EBS_RULE_BASE |
| EBS | ZCL_CD_EBS_R_R19_FI_DOCUMENT | covered | 0 | ZCL_CD_EBS_RULE_BASE |
| EBS | ZCL_CD_EBS_R_R21_LOOKUP | covered | 0 | ZCL_CD_EBS_RULE_BASE |
| EBS | ZCL_CD_EBS_R_R22_DUP_HISTORY | covered | 0 | ZCL_CD_EBS_RULE_BASE |
| EBS | ZCL_CD_EBS_R_S01_CONTINUITY | covered | 0 | ZCL_CD_EBS_RULE_BASE |
| EBS | ZCL_CD_EBS_R_S02_BALANCE | covered | 0 | ZCL_CD_EBS_RULE_BASE |
| EBS | ZCL_CD_EBS_R_S03_SEQUENCE | covered | 0 | ZCL_CD_EBS_RULE_BASE |
| EBS | ZCL_CD_EBS_R_S04_ACCOUNT | covered | 0 | ZCL_CD_EBS_RULE_BASE |
| EBS | ZCL_CD_EBS_R_S05_DATE | covered | 0 | ZCL_CD_EBS_RULE_BASE |
| EBS | ZCL_CD_EBS_R_S07_DUPLICATE | covered | 0 | ZCL_CD_EBS_RULE_BASE |
| EBS | ZCL_CD_EBS_R_S09_COVERAGE | covered | 0 | ZCL_CD_EBS_RULE_BASE |
| EBS | ZCL_CD_EBS_R_S10_COMPLETE | covered | 0 | ZCL_CD_EBS_RULE_BASE |
| EBS | ZCL_CD_EBS_R_S12_COUNT | covered | 0 | ZCL_CD_EBS_RULE_BASE |
| EBS | ZCL_CD_EBS_R_S13_POSTED | covered | 0 | ZCL_CD_EBS_RULE_BASE |
| EBS | ZCL_CD_EBS_SAP_DAO | own test include | 15 | partial: GET_RETRIEVALS select on ZCD_ACH_RTRV_LOG (VERIFY-DDIC status field) - QA1; its field check is unit tested |
| EBS | ZCL_CD_EBS_SRC_FEB | own test include | 11 |  |
| EBS | ZCL_CD_EBS_SRC_FILE | own test include | 4 |  |
| FMON | ZBP_R_CD_FMONCFGALL | own test include | 4 | partial: global authorization tested (EML GET PERMISSIONS ONLY GLOBAL AUTHORIZATION - per activity 01 / 02 / 06 and none, root and first child, VERIFY-ADT); global features, validations and saver need GET PERMISSIONS FEATURES or draft EML with COMMIT ENTITIES, which the offline lint (abaplint 2.120.92) does not parse - DV1 cases RAP_Config_Apps.md 6; decisions tested in ZCL_CD_OPS_CFG_GATE / _CHECKS / _POLICY |
| FMON | ZBP_R_CD_FMONFILE | own test include | 2 | partial: global authorization tested (EML GET PERMISSIONS, VERIFY-ADT); actions, determinations, validations and saver need EML with COMMIT ENTITIES on doubled tables - QA1 cases RAP_Ops_Apps.md 5; decisions tested in the policy classes |
| FMON | ZBP_R_CD_FMONPRQWA | own test include | 2 | partial: global authorization tested (EML GET PERMISSIONS, VERIFY-ADT); actions, determinations, validations and saver need EML with COMMIT ENTITIES on doubled tables - QA1 cases RAP_Ops_Apps.md 5; decisions tested in the policy classes |
| FMON | ZCL_CD_FMON_ADAPTER_GENERIC | own test include | 10 |  |
| FMON | ZCL_CD_FMON_ADAPTER_PRISM | own test include | 5 |  |
| FMON | ZCL_CD_FMON_CALENDAR | own test include | 9 |  |
| FMON | ZCL_CD_FMON_CHK_ACK_MATCH | covered | 0 | ZCL_CD_FMON_ENGINE |
| FMON | ZCL_CD_FMON_CHK_DUPLICATE | covered | 0 | ZCL_CD_FMON_ENGINE |
| FMON | ZCL_CD_FMON_CHK_LATE | covered | 0 | ZCL_CD_FMON_ENGINE |
| FMON | ZCL_CD_FMON_CHK_LOT | covered | 0 | ZCL_CD_FMON_ENGINE |
| FMON | ZCL_CD_FMON_CHK_MISSING | covered | 0 | ZCL_CD_FMON_ENGINE |
| FMON | ZCL_CD_FMON_CHK_NOC_AGING | covered | 0 | ZCL_CD_FMON_ENGINE |
| FMON | ZCL_CD_FMON_CHK_PRISM_FILE | own test include | 5 |  |
| FMON | ZCL_CD_FMON_CHK_REJECT | own test include | 2 |  |
| FMON | ZCL_CD_FMON_CHK_SIZE | covered | 0 | ZCL_CD_FMON_ENGINE |
| FMON | ZCL_CD_FMON_CHK_SLA | covered | 0 | ZCL_CD_FMON_ENGINE |
| FMON | ZCL_CD_FMON_DAO | own test include | 24 | partial: READ_LEGACY / SELECT_LEGACY dynamic reads of legacy structures and the EVENT_NO collision retry (two sessions) - QA1 FMON 01, 05, 07, 08, 10, 11 |
| FMON | ZCL_CD_FMON_DDIC | own test include | 6 |  |
| FMON | ZCL_CD_FMON_ENGINE | own test include | 42 |  |
| FMON | ZCL_CD_FMON_FACTORY | covered | 0 | ZCL_CD_FMON_ENGINE |
| FMON | ZCL_CD_FMON_FLOW_CDS_TEST | own test include | 20 |  |
| FMON | ZCL_CD_FMON_INJECTOR | covered | 0 | ZCL_CD_FMON_ENGINE |
| FMON | ZCL_CD_FMON_LOT_READER | own test include | 7 |  |
| FMON | ZCL_CD_FMON_OPS_POLICY | own test include | 5 |  |
| FMON | ZCL_CD_FMON_PRISM_API | own test include | 11 |  |
| FMON | ZCL_CD_FMON_PRISM_DAO | own test include | 5 |  |
| FMON | ZCL_CD_FMON_PRISM_EVENT | own test include | 20 |  |
| FMON | ZCL_CD_FMON_PRISM_HTTP | own test include | 2 |  |
| FMON | ZCL_CD_FMON_PRISM_OP | own test include | 1 |  |
| FMON | ZCL_CD_FMON_PRISM_PROC | own test include | 11 |  |
| FMON | ZCL_CD_FMON_PRISM_QUEUE | own test include | 1 | partial: CX_BGMC branch not injected: CX_BGMC instantiation is VERIFY-ADT on 7.58 SP01 - QA case PRISM-12 |
| FMON | ZCL_CD_FMON_QUERY | own test include | 8 |  |
| FMON | ZCL_CD_FMON_RULES | own test include | 74 |  |
| FMON | ZCL_CD_FMON_STATUS | own test include | 24 |  |
| FMON | ZCL_CD_FMON_UTIL | own test include | 5 |  |
| HCK | ZBP_R_CD_HCKCFGALL | own test include | 4 | partial: global authorization tested (EML GET PERMISSIONS ONLY GLOBAL AUTHORIZATION - per activity 01 / 02 / 06 and none, root and first child, VERIFY-ADT); global features, validations and saver need GET PERMISSIONS FEATURES or draft EML with COMMIT ENTITIES, which the offline lint (abaplint 2.120.92) does not parse - DV1 cases RAP_Config_Apps.md 6; decisions tested in ZCL_CD_OPS_CFG_GATE / _CHECKS / _POLICY |
| HCK | ZBP_R_CD_HCKSUPPRESS | own test include | 2 | partial: global authorization tested (EML GET PERMISSIONS, VERIFY-ADT); actions, determinations, validations and saver need EML with COMMIT ENTITIES on doubled tables - QA1 cases RAP_Ops_Apps.md 5; decisions tested in the policy classes |
| HCK | ZCL_CD_HCK_AGG_QUERY | own test include | 14 |  |
| HCK | ZCL_CD_HCK_BUDGET | own test include | 3 |  |
| HCK | ZCL_CD_HCK_CANONICAL | own test include | 3 |  |
| HCK | ZCL_CD_HCK_CYCLE_EVAL | own test include | 14 |  |
| HCK | ZCL_CD_HCK_C_ALERT_HEALTH | own test include | 3 |  |
| HCK | ZCL_CD_HCK_C_APPLOG | own test include | 4 |  |
| HCK | ZCL_CD_HCK_C_CHQ_STATUS | own test include | 4 |  |
| HCK | ZCL_CD_HCK_C_CONFIG_DRIFT | own test include | 6 |  |
| HCK | ZCL_CD_HCK_C_GENERIC_AGG | own test include | 5 |  |
| HCK | ZCL_CD_HCK_C_GL_TRANSFER | own test include | 5 |  |
| HCK | ZCL_CD_HCK_C_JOB_CYCLE | own test include | 6 |  |
| HCK | ZCL_CD_HCK_C_JOB_RUNTIME | own test include | 3 |  |
| HCK | ZCL_CD_HCK_C_OVERDUE_EXC | own test include | 2 |  |
| HCK | ZCL_CD_HCK_C_PRQ_CANCEL | own test include | 4 |  |
| HCK | ZCL_CD_HCK_C_PRQ_SPE | own test include | 3 |  |
| HCK | ZCL_CD_HCK_C_TECH_JOBS | own test include | 9 |  |
| HCK | ZCL_CD_HCK_C_TECH_SYS | own test include | 2 |  |
| HCK | ZCL_CD_HCK_C_VOLUME | own test include | 2 |  |
| HCK | ZCL_CD_HCK_DAO | own test include | 28 | partial: technical reads SNAP / VBHDR / ENQUEUE_READ (COUNT_SHORT_DUMPS, COUNT_UPDATE_ERRORS, READ_LOCK_STATS), IS_WORKING_DAY (calendar FM) and the success path of dynamic AGGREGATE / SELECT_VALUES / COMPUTE_TABLE_HASH on landscape tables - QA1 |
| HCK | ZCL_CD_HCK_DASH_CDS_TEST | own test include | 7 |  |
| HCK | ZCL_CD_HCK_DATASET | own test include | 4 | partial: success path of OPEN / TRANSFER DATASET writes to the application server - QA1 (error paths unit tested, nothing written) |
| HCK | ZCL_CD_HCK_ENGINE | own test include | 22 |  |
| HCK | ZCL_CD_HCK_EXPORT | own test include | 3 |  |
| HCK | ZCL_CD_HCK_FACTORY | covered | 0 | ZCL_CD_HCK_ENGINE |
| HCK | ZCL_CD_HCK_INJECTOR | covered | 0 | ZCL_CD_HCK_ENGINE |
| HCK | ZCL_CD_HCK_PARAM | own test include | 8 |  |
| HCK | ZCL_CD_HCK_PAYREQ_RULES | own test include | 8 |  |
| HCK | ZCL_CD_HCK_REPORT_HTML | own test include | 8 |  |
| HCK | ZCL_CD_HCK_SCORE | own test include | 6 |  |
| HCK | ZCL_CD_HCK_STATS | own test include | 12 |  |
| HCK | ZCL_CD_HCK_SUPPRESSION | own test include | 11 |  |
| HCK | ZCL_CD_HCK_THRESHOLD | own test include | 16 |  |
| HCK | ZCL_CD_HCK_VALUE_QUERY | own test include | 6 |  |

### Requirements baseline acceptance tests mapped to proof

| # | Acceptance test | Proof |
|---|---|---|
| 1 | New health check by customizing (return debits aging > 10 days by company code) | `ZCD_HCK_AGG` generic check; `ltc_agg_query`; QA1 HCK-QA-01 |
| 2 | New source and LOB by customizing | FMON `new_source_uses_default_iface`; QA1 FMON-13 |
| 3 | New BTC code with rules by customizing | EBS `new_code_needs_config_only`; QA1 EBS-03 |
| 4 | New validation rule by customizing (closing deviates > 0.01) | EBS `s01_deviation_within_toler` + ZCD_BTC_RULE row; QA1 EBS-04 |
| 5 | New job-cycle step by customizing | HCK `ltc_cycle_eval`; QA1 HCK-QA-06 |
| 6 | 10M+ open items, runtime and < 5 % DB load | Not provable offline — QA1 performance test (Test and Validation §11) |
| 7 | Unmapped BTC never posts | EBS `unmapped_btc_always_blocks`, `unmapped_code_always_blocked` |
| 8 | Returns/NOC with unprocessed item stays PARTIALLY_PROCESSED and alerts | FMON `partial_returns_stay_partial`, `partial_returns_are_alerted`, `source_cannot_close_open_lot` |

## 5. Deliberately not unit tested (or only in part), and why

Updated 2026-11-06 (coverage gap closure): the SAP-service wrappers, the HCK checks, the FMON calendar /
DDIC wrappers, the PRISM ICF handler / bgPF classes, the EBS factory and the DAO reads that had no test now
have their own tests. Production code got test seams only where a kernel or SAP API call had to be replaced;
each is listed in the modification log of its class.

| Test seam(s) | Class | Replaces |
|---|---|---|
| `AUTH_AREA`, `AUTH_BUKRS` | ZCL_CD_OPS_AUTH | `AUTHORITY-CHECK` on ZCD_OPS |
| `ENQUEUE`, `DEQUEUE` | ZCL_CD_OPS_LOCK | `ENQUEUE_E_TABLE` / `DEQUEUE_E_TABLE` (return code and holder kept in locals) |
| `BAL_CREATE`, `BAL_ADD`, `BAL_SAVE`, `BAL_REFRESH` | ZCL_CD_OPS_CHN_APPLOG | BAL function modules |
| `BCS_SEND`, `BCS_COMMIT` | ZCL_CD_OPS_CHN_EMAIL | BCS send and its `COMMIT WORK` (BCS error kept in a local) |
| `CTS_API` | ZCL_CD_OPS_CFG_TRANSPORT | `MBC_CP_API` recording (API error kept in a local) |
| `TO_FACTORY_DATE`, `TO_DATE` | ZCL_CD_FMON_CALENDAR | factory calendar function modules |
| `TABLE_AUTH` | ZCL_CD_FMON_DDIC | `AUTHORITY-CHECK` S_TABU_NAM |
| `BGPF` | ZCL_CD_FMON_PRISM_QUEUE | bgPF process factory (error kept in a local) |

Injections never modify SY fields and never raise (the ATC-equivalent rules `sy_modification` /
`uncaught_exception` see injection code as test code): the production code keeps return codes and caught
exceptions in local variables, the injection sets those.

What remains outside ABAP Unit (each with its register row and the case that covers it):

| Object | What is not unit tested | Reason | Covered instead by |
|---|---|---|---|
| ZBP_R_CD_OPSEXCEPTION | whole pool (exempt) | instance authorization / features and the four actions read persisted findings: EML with COMMIT ENTITIES on doubled tables, not parsed by the offline lint | `ZCL_CD_OPS_EXC_POLICY`; QA1 OPS-01 … OPS-08 |
| ZBP_R_CD_*CFGALL (4, generated) | global features, validations, saver | `GET PERMISSIONS … FEATURES` and the handler-direct fallback (`CREATE OBJECT … FOR TESTING`, `LOCAL FRIENDS` of a local handler) are not parsed by abaplint 2.120.92 | global authorization tested (EML `GET PERMISSIONS ONLY GLOBAL AUTHORIZATION`, VERIFY-ADT); gate / checks / policy tests; DV1 cases `RAP_Config_Apps.md` §6 |
| ZBP_R_CD_FMONFILE, _FMONPRQWA, _HCKSUPPRESS | actions, determinations, validations, saver | as above | global authorization tested (VERIFY-ADT); policy tests; QA1 `RAP_Ops_Apps.md` §5 |
| ZCL_CD_HCK_DATASET | success path of OPEN / TRANSFER DATASET | writes to the application server | error paths unit tested (nothing written); QA1 |
| ZCL_CD_FMON_PRISM_QUEUE | `CX_BGMC` branch | instantiating `CX_BGMC` is VERIFY-ADT on 7.58 SP01 | QA PRISM-12 |
| ZCL_CD_FMON_DAO | READ_LEGACY / SELECT_LEGACY, EVENT_NO collision retry | unknown legacy structures; a collision needs two sessions | OSQL tests for idempotency and numbering; QA1 FMON 01, 05, 07, 08, 10, 11 |
| ZCL_CD_HCK_DAO | SNAP / VBHDR / ENQUEUE_READ reads, calendar FM, success path of dynamic aggregate / value query / table hash | standard tables / FMs with unverified fields, landscape tables | pure evaluators + checks with DAO doubles; QA1 |
| ZCL_CD_EBS_SAP_DAO | GET_RETRIEVALS select | ZCD_ACH_RTRV_LOG status field VERIFY-DDIC | field check unit tested; QA1 |
| ZCL_CD_OPS_TRACE_DAO | reads delegated to the EBS SAP DAO / FMON reader | tested in those classes | — |
| ZCL_CD_OPS_STORE | COMMIT / ROLLBACK | one statement each | engine LUW tests with the store double |
| Reports ZCD_EBS_VALIDATE, ZCD_FMON_MONITOR, ZCD_MORNING_REPORT, ZCD_OPS_PURGE | selection screen, authorisation and ALV | programs, not classes | QA1 functional cases |
| CDS views and DCL (`cds/` analytics; DCL `ZC_CD_FMONFLOW`, UI annotations) | DCL and UI rendering | not executable offline | CDS test classes; ADT data preview in DV1; QA1 dashboard cases |

## 6. What to run, and when

| When | What |
|---|---|
| Every activation | The class's own test include |
| Before releasing a transport | All HARMLESS test classes of the package (`ZCD_OPS*`) |
| QA1 before go-live | Functional cases in `Test_and_Validation_Document.md`, the EBS shadow run against the legacy validators, the performance test |
| Before a new bank / source / code goes live | Package run + the payment engine area's QA1 cases for that configuration |

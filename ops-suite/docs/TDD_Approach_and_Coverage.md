# TDD approach and coverage — Operations Suite

> **First principle:** if something is hard to test, it is in the wrong layer.
> **Analogy:** a recipe is tasted at every step, not only when the dish is served.

## 1. Why the architecture is shaped this way

- **Domain classes hold no SQL and call no function modules.** Rules (`ZCL_CD_EBS_R_*`), resolvers, policies (`ZCL_CD_OPS_ALERT_POLICY`), status machines (`ZCL_CD_FMON_STATUS`), evaluation rules (`ZCL_CD_FMON_RULES`, `ZCL_CD_HCK_CYCLE_EVAL`), statistics and renderers work on structures. Tests build them field by field and assert the result.
- **Everything touching the outside world is behind an interface** — store, alert router, alert DAO, channels, clock, EBS/FMON/HCK repositories, parsers, sources, calendar, DDIC describer. Engines get them from the factories, so tests inject `LTD_*` doubles and assert what the engine *did*.
- **Plug-ins are registry rows, not a `CASE`.** A new rule, check, adapter or channel is a new class plus a customizing row, so its test is new too — no existing test changes.

## 2. The loop

**Red** — write the failing test in the class that owns the behaviour, named after the rule (`unmapped_btc_always_blocks`, `partial_returns_stay_partial`, `stuck_step_after_max_runtime`). **Green** — make it pass in the smallest correct place. **Refactor** — move shared logic into the base/helper classes with the tests as the safety net. **Parity** — any behaviour change against the legacy validators gets a row in `Legacy_Parity_Comparison.md` in the same change.

### How strictly the loop was followed in this build (honest record)

| Order | Objects | Evidence |
|---|---|---|
| **Test first** — test include written before the class; lint failed ("class/method not found") until the class existed | `ZCL_CD_EBS_BTC_RESOLVER`, `ZCL_CD_OPS_ALERT_POLICY`, `ZCL_CD_OPS_ALERT_ROUTER`, the 26 `ZCL_CD_EBS_R_*` rules (via `ZCL_CD_EBS_RULE_BASE` test include), `ZCL_CD_EBS_ENGINE`, `ZCL_CD_EBS_SRC_FEB` | Red state observed by the lead developer in the lint output |
| **Test first — reported, not independently verifiable** | `ZCL_CD_EBS_PARSER_BAI2`, `ZCL_CD_EBS_PARSER_CAMT`, all FMON and HCK classes with test includes | Stated in the hand-over reports of the developers who built them; no file history records the order |
| **Test after** (characterisation tests, written once the class existed) | `ZCL_CD_OPS_UTIL`, `ZCL_CD_OPS_STORE`, `ZCL_CD_EBS_CFG_DAO`, `ZCL_CD_EBS_FEB_DAO`, `ZCL_CD_EBS_SAP_DAO` (written before the TDD approach was adopted for this build); `ZCL_CD_EBS_FINDING`, `ZCL_CD_OPS_FACTORY` (plug-in creation), `ZCL_CD_OPS_CHN_HTTP` (`TO_JSON`), `ZCL_CD_EBS_SRC_FILE` (gap closure, 2026-11-06) | Modification log of each test include |
| **Test first, audit fixes 2026-11-06** — test written before the fix, fix written after; not executed (no ABAP Unit offline) | `ZCL_CD_EBS_ENGINE` (`failed_rule_blocks_posting`, `broken_config_blocks_posting`), `ZCL_CD_FMON_ENGINE` (`alerts_sent_after_commit`, `persist_error_rolls_back`), `ZCL_CD_HCK_ENGINE` (`alerts_sent_after_commit`) | `Review_Response_2026-11-06.md` part B |
| **Test first, core controls 2026-11-06** — test written before the code it drives; lint red until the code existed; not executed | `ZCL_CD_OPS_RUN_GUARD`, `ZCL_CD_OPS_PURGE`, `ZCL_CD_OPS_PURGE_DAO`, store carry-forward / `reconcile` (7 OSQL tests), engine lock and reconciliation tests (EBS 4, FMON 4, HCK 3), `injected_auth_is_returned` | `RAP_Apps_Design.md` §1–§4; commit history of 2026-11-06 |
| **Test first, configuration apps** — red observed in abaplint (47 "not found") before the classes existed | `ZCL_CD_OPS_CFG_POLICY`, `ZCL_CD_OPS_CFG_CHECKS`, `ZCL_CD_OPS_CFG_GATE` | Phase 2 hand-over |
| **Test first, EBS rule audit** (part C) | 7 rule tests (`r07_any_run_with_status_ok` … `r18_unmapped_gl_reported`) written before the fixes | `Review_Response_2026-11-06.md` part C |
| **Test first, operations apps** (phase 3) — tests written before each class / engine change; not executed | `ZCL_CD_OPS_EXC_POLICY`, `ZCL_CD_OPS_EXC_DAO`, `ZCL_CD_EBS_RELEASE_POLICY`, `ZCL_CD_EBS_RELEASE_DAO`, `ZCL_CD_HCK_SUPPRESSION`, `ZCL_CD_HCK_PAYREQ_RULES`, `ZCL_CD_HCK_VALUE_QUERY`, `ZCL_CD_FMON_OPS_POLICY`, `ZCL_CD_FMON_STATUS=>MANUAL_ALLOWED`; engine tests for release and suppression; store `pending_waiver_is_carried` | `RAP_Ops_Apps.md` §3 |
| **Test after (characterisation)**, phase 3 | `success_wins_over_later_fail`, `success_after_fail_wins` (existing state-machine behaviour, pinned for the PRISM SUCCESS rule) | `RAP_Ops_Apps.md` §3 |
| **No unit test by design** | See §5 | Covered by the listed alternative |

**What "red" and "green" mean here.** In this build red was a test that did not compile against missing code and green was a clean abaplint run. That proves each test targets the new code; it does **not** prove the tests pass. True red/green — an assertion failing, then passing — happens at the first ABAP Unit run in DV1. Until then no test result exists.

## 3. Test levels

| Level | Runs | Covers | Isolation | Cost |
|---|---|---|---|---|
| Domain | always | rules, resolvers, policies, statistics, renderers, parsers | none | free |
| Application | always | engines: orchestration, persistence calls, alerts, circuit breaker, test mode | `LTD_*` doubles via injectors | free |
| OSQL | always | repository SQL: filters, keys, ordering, idempotency, empty-key guards | `cl_osql_test_environment` | cheap |
| Integration | QA1 only | wrappers over SAP standard (BCS, BAL, HTTP, factory calendar, RTTI, TBTCO/BALHDR/SNAP/VBHDR reads, dynamic SQL on legacy tables) | `RISK LEVEL DANGEROUS`, TVARVC-gated, functional test cases | manual |

## 4. Coverage today — 455 ABAP Unit methods in 47 test includes

| Module | Object (test include) | Methods | Level |
|---|---|---|---|
| Core | ZCL_CD_OPS_UTIL | 12 | Domain |
| Core | ZCL_CD_OPS_ALERT_POLICY | 14 | Domain |
| Core | ZCL_CD_OPS_ALERT_ROUTER | 8 | Application |
| Core | ZCL_CD_OPS_STORE (incl. exception carry-forward and reconciliation) | 13 | OSQL |
| Core | ZCL_CD_OPS_FACTORY (plug-in creation, injection seams) | 7 | Domain |
| Core | ZCL_CD_OPS_RUN_GUARD (refused run when the run lock is held) | 4 | Application |
| Core | ZCL_CD_OPS_PURGE (retention rules, packages, test mode) | 5 | Domain / Application |
| Core | ZCL_CD_OPS_PURGE_DAO | 7 | OSQL |
| Core | ZCL_CD_OPS_CHN_HTTP (`TO_JSON` only) | 3 | Domain |
| Core | ZCL_CD_OPS_CFG_POLICY (configuration apps: client policy) | 11 | Domain |
| Core | ZCL_CD_OPS_CFG_CHECKS (configuration apps: field validations) | 17 | Domain |
| Core | ZCL_CD_OPS_CFG_GATE (configuration apps: features, transport, authorisation) | 7 | Application |
| Core | ZCL_CD_OPS_EXC_POLICY (exceptions app: lifecycle, four-eyes) | 9 | Domain |
| Core | ZCL_CD_OPS_EXC_DAO (find open, resolve with history) | 2 | OSQL |
| EBS | ZCL_CD_EBS_RELEASE_POLICY (blocked-line release) | 6 | Domain |
| EBS | ZCL_CD_EBS_RELEASE_DAO | 1 | OSQL |
| FMON | ZCL_CD_FMON_OPS_POLICY (manual status, PRISM handled manually) | 5 | Domain |
| HCK | ZCL_CD_HCK_SUPPRESSION (suppression matcher, four-eyes) | 8 | Domain |
| HCK | ZCL_CD_HCK_PAYREQ_RULES (known-table rules: SPE, CANCELLED, ZECT_STATUS) | 8 | Domain |
| HCK | ZCL_CD_HCK_VALUE_QUERY (DDIC-checked value queries) | 6 | Domain |
| EBS | ZCL_CD_EBS_BTC_RESOLVER | 13 | Domain |
| EBS | ZCL_CD_EBS_FINDING | 5 | Domain |
| EBS | ZCL_CD_EBS_SRC_FILE | 4 | Application |
| EBS | ZCL_CD_EBS_RULE_BASE (LTC_LINE_RULES, LTC_LOOKUP_RULES, LTC_STMT_RULES — all 26 rule classes) | 43 | Domain / Application |
| EBS | ZCL_CD_EBS_PARSER_BAI2 | 17 | Domain |
| EBS | ZCL_CD_EBS_PARSER_CAMT | 14 | Domain |
| EBS | ZCL_CD_EBS_SRC_FEB | 6 | Application |
| EBS | ZCL_CD_EBS_ENGINE | 21 | Application |
| EBS | ZCL_CD_EBS_CFG_DAO / _FEB_DAO / _SAP_DAO | 3 + 3 + 3 | OSQL |
| FMON | ZCL_CD_FMON_STATUS | 15 | Domain |
| FMON | ZCL_CD_FMON_RULES | 35 | Domain |
| FMON | ZCL_CD_FMON_QUERY | 5 | Domain |
| FMON | ZCL_CD_FMON_ADAPTER_GENERIC | 6 | Domain / Application |
| FMON | ZCL_CD_FMON_LOT_READER | 3 | Application |
| FMON | ZCL_CD_FMON_ENGINE | 17 | Application |
| FMON | ZCL_CD_FMON_DAO | 6 | OSQL |
| HCK | ZCL_CD_HCK_STATS / _THRESHOLD / _SCORE / _CYCLE_EVAL / _AGG_QUERY / _REPORT_HTML / _PARAM | 12 + 11 + 6 + 11 + 12 + 7 + 3 | Domain |
| HCK | ZCL_CD_HCK_ENGINE | 14 | Application |
| HCK | ZCL_CD_HCK_DAO | 5 | OSQL |

Coverage targets: ≥ 90 % statements per object (house), ≥ 85 % (master prompt). **Measured coverage: none yet** — record it in `Coverage_Run_Register.csv` after the first DV1 run.

### Master prompt acceptance tests mapped to proof

| # | Acceptance test | Proof |
|---|---|---|
| 1 | New health check by customizing (return debits aging > 10 days by company code) | `ZCD_HCK_AGG` generic check; `ltc_agg_query`; QA1 HCK-QA-01 |
| 2 | New source and LOB by customizing | FMON `new_source_uses_default_iface`; QA1 FMON-13 |
| 3 | New BTC code with rules by customizing | EBS `new_code_needs_config_only`; QA1 EBS-03 |
| 4 | New validation rule by customizing (closing deviates > 0.01) | EBS `s01_deviation_within_toler` + ZCD_BTC_RULE row; QA1 EBS-04 |
| 5 | New job-cycle step by customizing | HCK `ltc_cycle_eval`; QA1 HCK-QA-06 |
| 6 | 10M+ open items, runtime and < 5 % DB load | Not provable offline — QA1 performance test (Test and Validation §11) |
| 7 | Unmapped BTC never posts | EBS `unmapped_btc_always_blocks`, `unmapped_code_always_blocked`, `enforce_mode_blocks_posting` |
| 8 | Returns/NOC with unprocessed item stays PARTIALLY_PROCESSED and alerts | FMON `partial_returns_stay_partial`, `partial_returns_are_alerted`, `source_cannot_close_open_lot` |

## 5. Deliberately not unit tested, and why

| Object | Reason | Covered instead by |
|---|---|---|
| ZCL_CD_OPS_CHN_EMAIL / _APPLOG, delivery part of _HTTP | Thin wrappers over BCS, BAL, CL_HTTP_CLIENT; a double would only assert that we call what we call | Router tests with a channel double; QA1 alert cases; the JSON body of _HTTP is unit tested |
| ZCL_CD_OPS_ALERT_DAO | Three SELECTs and one INSERT | Router tests with DAO double; QA1 |
| ZCL_CD_OPS_INJECTOR, ZCL_CD_EBS/_FMON/_HCK_FACTORY / _INJECTOR | Construction only | Every application test resolves its CUT through them; plug-in creation of the core factory is unit tested |
| ZCL_CD_OPS_CLOCK | Two system-field reads | Injected clock doubles in every time-dependent test |
| Behaviour pools `ZBP_R_CD_OPSEXCEPTION`, `_EBSRELEASE`, `_HCKSUPPRESS`, `_FMONFILE`, `_FMONPRQWA`; their CDS, BDEF, SRVD | Thin handlers: every decision in a tested policy class | Policy tests; QA1 OPS-01 … OPS-10 (`RAP_Ops_Apps.md` §5) |
| Check classes `ZCL_CD_HCK_C_PRQ_SPE`, `_C_CHQ_STATUS`, `_C_PRQ_CANCEL` | Parameter reading + DAO calls; rules in `ZCL_CD_HCK_PAYREQ_RULES`, queries in `ZCL_CD_HCK_VALUE_QUERY` (both tested) | QA1 HCK-QA-15 … 17 |
| `ZCL_CD_HCK_DAO=>SELECT_VALUES` | Dynamic read of a validated query on landscape tables with unconfirmed fields | Builder tests; QA1 |
| Behaviour pools `ZBP_R_CD_*CFGALL`, CDS, BDEF, SRVD of the configuration apps | Generated (`tools/rap_generate.py`), thin | Gate / checks tests; DV1 cases `RAP_Config_Apps.md` §6 |
| ZCL_CD_OPS_CFG_CLIENT, ZCL_CD_OPS_CFG_TRANSPORT, ZCL_CD_OPS_CFG_AUTH | T000 / E070 reads, SAP CTS API wrapper, adapter to ZCL_CD_OPS_AUTH | Gate tests with doubles; DV1 |
| ZCL_CD_OPS_AUTH | One `AUTHORITY-CHECK` on ZCD_OPS; a test would assert the kernel | Injected auth double (`injected_auth_is_returned`); QA1 role tests (allowed / refused per activity and module) |
| ZCL_CD_OPS_LOCK | `ENQUEUE_E_TABLE` / `DEQUEUE_E_TABLE` (`VERIFY-SE37`) | Engine tests with a lock double (held lock, release); QA1: two parallel runs of the same variant — the second is refused with RUN_LOCKED |
| ZCL_CD_EBS_RULE_BASE | Abstract | Through the 26 rule classes |
| ZCL_CD_EBS_ENGINE=>READ_MODE | Kill-switch read of TVARVC (deliberately no factory) | `must_block` tests per mode; QA1 switch cases |
| ZCL_CD_EBS_SAP_DAO (retrievals, checks, FI lines, G/L balance) | Fields `VERIFY-DDIC` until SE11 confirms them | Rule tests with SAP-DAO double; OSQL tests for confirmed paths; QA1 |
| ZCL_CD_FMON_DAO=>INSERT_EVENT — EVENT_NO collision retry | A collision needs two sessions inserting at once; one OSQL session always sees its own MAX | OSQL tests for idempotency and numbering; QA1: two parallel `ZCD_FMON_MONITOR` runs for the same date, then every source event recorded exactly once |
| ZCL_CD_FMON_CALENDAR, ZCL_CD_FMON_DDIC, ZCL_CD_FMON_DAO=>READ_LEGACY | Factory calendar FMs, RTTI, unknown legacy structures | Pure rules + engine with doubles; QA1 FMON 01, 05, 07, 08, 10, 11 |
| 9 FMON check classes, 11 HCK check classes | Thin loops over pure rule classes | Rule tests + engine tests with every check configured |
| ZCL_CD_HCK_DAO technical reads (TBTCO, BALHDR, SNAP, VBHDR, ENQUEUE_READ) | Standard tables / FMs with unverified fields | Pure evaluators + QA1 |
| Reports ZCD_EBS_VALIDATE, ZCD_FMON_MONITOR, ZCD_MORNING_REPORT, ZCD_OPS_PURGE | Selection screen, authorisation and ALV | QA1 functional cases |
| CDS views and DCL | Not parseable offline | ADT data preview in DV1; QA1 dashboard case |

## 6. What to run, and when

| When | What |
|---|---|
| Every activation | The class's own test include |
| Before releasing a transport | All HARMLESS test classes of the package (`ZCD_OPS*`) |
| QA1 before go-live | Functional cases in `Test_and_Validation_Document.md`, the EBS shadow run against the legacy validators, the performance test |
| Before a new bank / source / code goes live | Package run + the module's QA1 cases for that configuration |

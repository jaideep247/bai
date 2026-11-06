# TDD approach and coverage — Operations Suite

> **First principle:** if something is hard to test, it is in the wrong layer.
> **Analogy:** a recipe is tasted at every step, not only when the dish is served.

## 1. Why the architecture is shaped this way

- **Domain classes hold no SQL and call no function modules.** Rules (`ZCL_CD_EBS_R_*`), resolvers, policies (`ZCL_CD_OPS_ALERT_POLICY`), status machines (`ZCL_CD_FMON_STATUS`), evaluation rules (`ZCL_CD_FMON_RULES`, `ZCL_CD_HCK_CYCLE_EVAL`), statistics and renderers work on structures. Tests build them field by field and assert the result.
- **Everything touching the outside world is behind an interface** — store, alert router, alert DAO, channels, clock, EBS/FMON/HCK repositories, parsers, sources, calendar, DDIC describer. Engines get them from the factories, so tests inject `LTD_*` doubles and assert what the engine *did*.
- **Plug-ins are registry rows, not a `CASE`.** A new rule, check, adapter or channel is a new class plus a customizing row, so its test is new too — no existing test changes.

## 2. The loop

**Red** — write the failing test in the class that owns the behaviour, named after the rule (`unmapped_btc_always_blocks`, `partial_returns_stay_partial`, `stuck_step_after_max_runtime`). **Green** — make it pass in the smallest correct place. **Refactor** — move shared logic into the base/helper classes with the tests as the safety net. **Parity** — any behaviour change against the legacy validators gets a row in `Legacy_Parity_Comparison.md` in the same change.

During this build every test include was written before its class and failed lint (unknown class/method) before the class existed; that red state is the evidence the test targets the new code.

## 3. Test levels

| Level | Runs | Covers | Isolation | Cost |
|---|---|---|---|---|
| Domain | always | rules, resolvers, policies, statistics, renderers, parsers | none | free |
| Application | always | engines: orchestration, persistence calls, alerts, circuit breaker, test mode | `LTD_*` doubles via injectors | free |
| OSQL | always | repository SQL: filters, keys, ordering, idempotency, empty-key guards | `cl_osql_test_environment` | cheap |
| Integration | QA1 only | wrappers over SAP standard (BCS, BAL, HTTP, factory calendar, RTTI, TBTCO/BALHDR/SNAP/VBHDR reads, dynamic SQL on legacy tables) | `RISK LEVEL DANGEROUS`, TVARVC-gated, functional test cases | manual |

## 4. Coverage today — 296 ABAP Unit methods in 29 test includes

| Module | Object (test include) | Methods | Level |
|---|---|---|---|
| Core | ZCL_CD_OPS_UTIL | 12 | Domain |
| Core | ZCL_CD_OPS_ALERT_POLICY | 14 | Domain |
| Core | ZCL_CD_OPS_ALERT_ROUTER | 8 | Application |
| Core | ZCL_CD_OPS_STORE | 5 | OSQL |
| EBS | ZCL_CD_EBS_BTC_RESOLVER | 13 | Domain |
| EBS | ZCL_CD_EBS_RULE_BASE (LTC_LINE_RULES, LTC_LOOKUP_RULES, LTC_STMT_RULES — all 26 rule classes) | 35 | Domain / Application |
| EBS | ZCL_CD_EBS_PARSER_BAI2 | 17 | Domain |
| EBS | ZCL_CD_EBS_PARSER_CAMT | 14 | Domain |
| EBS | ZCL_CD_EBS_SRC_FEB | 6 | Application |
| EBS | ZCL_CD_EBS_ENGINE | 11 | Application |
| EBS | ZCL_CD_EBS_CFG_DAO / _FEB_DAO / _SAP_DAO | 3 + 3 + 3 | OSQL |
| FMON | ZCL_CD_FMON_STATUS | 11 | Domain |
| FMON | ZCL_CD_FMON_RULES | 35 | Domain |
| FMON | ZCL_CD_FMON_QUERY | 5 | Domain |
| FMON | ZCL_CD_FMON_ADAPTER_GENERIC | 6 | Domain / Application |
| FMON | ZCL_CD_FMON_LOT_READER | 3 | Application |
| FMON | ZCL_CD_FMON_ENGINE | 11 | Application |
| FMON | ZCL_CD_FMON_DAO | 6 | OSQL |
| HCK | ZCL_CD_HCK_STATS / _THRESHOLD / _SCORE / _CYCLE_EVAL / _AGG_QUERY / _REPORT_HTML / _PARAM | 12 + 11 + 6 + 11 + 12 + 7 + 3 | Domain |
| HCK | ZCL_CD_HCK_ENGINE | 9 | Application |
| HCK | ZCL_CD_HCK_DAO | 4 | OSQL |

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
| ZCL_CD_OPS_CHN_EMAIL / _APPLOG / _HTTP | Thin wrappers over BCS, BAL, CL_HTTP_CLIENT; a double would only assert that we call what we call | Router tests with a channel double; QA1 alert cases; `ZCL_CD_OPS_CHN_HTTP=>to_json` is pure |
| ZCL_CD_OPS_ALERT_DAO | Three SELECTs and one INSERT | Router tests with DAO double; QA1 |
| ZCL_CD_OPS_FACTORY / _INJECTOR, ZCL_CD_EBS/_FMON/_HCK_FACTORY / _INJECTOR | Construction only | Every application test resolves its CUT through them |
| ZCL_CD_OPS_CLOCK | Two system-field reads | Injected clock doubles in every time-dependent test |
| ZCL_CD_EBS_RULE_BASE | Abstract | Through the 26 rule classes |
| ZCL_CD_EBS_SRC_FILE | Delegates to the parser | Parser tests + QA1 file cases |
| ZCL_CD_EBS_ENGINE=>READ_MODE | Kill-switch read of TVARVC (deliberately no factory) | `must_block` tests per mode; QA1 switch cases |
| ZCL_CD_EBS_SAP_DAO (retrievals, checks, FI lines, G/L balance) | Fields `VERIFY-DDIC` until SE11 confirms them | Rule tests with SAP-DAO double; OSQL tests for confirmed paths; QA1 |
| ZCL_CD_FMON_CALENDAR, ZCL_CD_FMON_DDIC, ZCL_CD_FMON_DAO=>READ_LEGACY | Factory calendar FMs, RTTI, unknown legacy structures | Pure rules + engine with doubles; QA1 FMON 01, 05, 07, 08, 10, 11 |
| 9 FMON check classes, 11 HCK check classes | Thin loops over pure rule classes | Rule tests + engine tests with every check configured |
| ZCL_CD_HCK_DAO technical reads (TBTCO, BALHDR, SNAP, VBHDR, ENQUEUE_READ) | Standard tables / FMs with unverified fields | Pure evaluators + QA1 |
| Reports ZCD_EBS_VALIDATE, ZCD_FMON_MONITOR, ZCD_MORNING_REPORT | Selection screen and ALV | QA1 functional cases |
| CDS views and DCL | Not parseable offline | ADT data preview in DV1; QA1 dashboard case |

## 6. What to run, and when

| When | What |
|---|---|
| Every activation | The class's own test include |
| Before releasing a transport | All HARMLESS test classes of the package (`ZCD_OPS*`) |
| QA1 before go-live | Functional cases in `Test_and_Validation_Document.md`, the EBS shadow run against the legacy validators, the performance test |
| Before a new bank / source / code goes live | Package run + the module's QA1 cases for that configuration |

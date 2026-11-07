# Ops Suite — Development Standards

> **First principle:** every result is evidence about money. Code must be configuration-driven, testable without a database, and honest about what was verified.
> **Analogy:** a railway signal box — routes (rules) are set in the control panel (customizing), not by re-laying track (code).

This page applies to every object in `ops-suite/`. Where two rules conflict, the order of precedence is:
1. **abap-standards** (payment engine house rules, below in §2) — authoritative
2. **sap-engine-redesign-pattern** (layers, configuration over code, recovery)
3. **sap-abap-unit-tests** (Clean ABAP test shape)
4. **sap-dev-guardrails** — classic track (on-prem S/4HANA 2023, SAP_BASIS 7.58): modern syntax where it does not contradict 1–3.

## 1. Landscape (ground truth)

- S/4HANA 2023, SAP_BASIS 7.58 SP01. Transport path DV1 → QA1 → PS4 (production).
- In business-facing text the system is the **payment engine** (not "FI-CA" / "FS-CD"), and EBS validation, file monitoring and the morning report are **payment engine areas** (not "modules"; design D-6). Technical names follow: `PE_AREA`, `ZCD_PE_AREA`, `gc_pe_area`.
- Middleware **PRISM** carries files and status; banks JPMC, BOA, PNC (BAI2, NACHA, Positive Pay); scheduling by Control-M.
- Sources: PCLM, BASE, ALPA, ALPL, HAL, ORCI, DIS (+ Collections, Life & Annuity) — never assume one source's behaviour applies to another.
- Confirmed join paths (do not invent others):

| Need | Path |
|---|---|
| Bank line → payment (methods E G H I J K L) | FEBEP-CHECT = BSEG-XREF2 = DFKKOP-AUGBL |
| Bank line → payment (method C, cheque) | DFKKCR-DOC1R = DFKKOP-AUGBL; DFKKCR-ZTNUM = FEBEP-CHECT |
| Return → payment | DFKKRP-SELW1 = DFKKOP-AUGBL |
| payment engine postings reached GL | DFKKSUMC-FIKEY = DFKKKO-FIKEY = BSEG-AWKEY |
| Cumulation group from bank | DPAYH LAUFD + LAUFI where DOC1R is not initial |
| Collections vs disbursements | TFK042Z-XEINZ |

- Tables that **exist**: DFKKNRK, DFKKNRP (NOC lots: KEYN1 lot, POSNA item, INFOF CHAR50), DFKKRAPT. Tables that **do not exist**: DFKKRNIT, DFKKRAFT.
- ZCD_PAYM_REQ_LOG: select ZZ_STATUS = SUCCESS, never the highest COUNTER.
- **Cross-area reads (2026-11-07):** a payment engine area may use another area's read through that area's interface and factory only (FMON FEB adapter → `ZIF_CD_EBS_STMT_EVIDENCE` via `ZCL_CD_EBS_FACTORY`); the dependency is one-way (EBS never references FMON) and documented in both area docs; the definition (e.g. posting-open) lives once, in the owning area.
- More confirmed facts (full list and sources: `USAA_Known_Tables.md` §1):
  - Request → open item: ZCD_PAYM_REQ_LOG FIN number = DFKKOP-ZZ_FIN_TRANS_NUM; request → partner: ZZ_MEMBER_NO = BUT000-BPEXT, read **with** SOURCE first, then without (legacy PCLM partners).
  - ZCD_SPE_EXCP_LOG: every payment-request failure needs an SPE row, or the hourly status job never reports it.
  - Cheque status domain ZECT_STATUS: 3 failed, 4 rejected, 9 returned are terminal; mailed 10 → returned 9 allowed; otherwise higher may overwrite lower, never the reverse.
  - PCLM cancellation: CANCELLED = money will not leave; a paid request must never be left CANCELLED.
  - DPAYH-ZZ_PAYMENT_STATUS is the live payment status; DFKKOP-ZZ_BILLPLANID sits on DFKKOP (no DFKKNRK join).
  - FEBEP-BUDAT is always filled; FEBEP-XBLNR is never blank for BAI 452 and holds bank text + 10-character payment engine bank account + counter (user, 2026-11-06 — the EBS scope, `EBS_VALIDATION.md` §A0a). BAI 143 / 452 are known unmapped codes (R14 blocks them until Treasury confirms a mapping).
  - TFK033D wildcard `*` does not work (enumerate); TVARVC refuses two type-P rows with the same name.
  - PRISM throttles ACH and wire files at 2 minutes per file before sending them to the bank; positive pay and stop pay are not throttled (user, 2026-11-06 — FMON delivery SLA allowance, `FMON_FILE_MONITORING.md` §A3a).
  - FPY1 locks EFKKCLEGPI per partner interval (GPART_V..GPART_B, one RUNKEY + BUKRS, _SCOPE 3) — design concurrency around partner ranges.
- FPY1 locks per partner interval; F.13 is not run for disbursement clearing accounts.
- ACK tables confirm payment-run files per pay cycle; Stripe payout, cost centre, BlackLine and GL OFSAA files have **no** ACK. Disbursements ACK per payment, collections per file.
- Control-M schedules `JQ4SP*`; SAP jobs `ZCD_<function>_<ENTITY>`; most run `RFKK_MA_SCHEDULER` or `ZICD_CALL_SM69_COMMAND_NEW`.

**Unverified DDIC.** Any field of a custom table (ZCD_ACH_ACK, ZCD_WIRE_ACK, ZCD_CHECK_HIST, ZCD_ACH_RTRV_LOG, ZCDT_REGUT, ZCD_STRP_POUT_LOG …) or any standard field not listed above is *unverified*. Do not hard-code it: read it through configuration (table/field names in customizing, validated against the DDIC at runtime with `cl_abap_typedescr`) or isolate it in one DAO method marked `"VERIFY-DDIC:`. List every such marker in the payment engine area README.

## 2. abap-standards (house rules — authoritative)

- Custom object prefix `_CD_` (never `_FSCD_`): `ZCL_CD_…`, `ZIF_CD_…`, `ZCX_CD_…`, tables `ZCD_…`.
- `FINAL` on every concrete class. Object names ≤ 30 chars; short texts ≤ 60 chars; test method names ≤ 30 chars.
- `describe_by_name` with classic `EXCEPTIONS`/`sy-subrc`; wrap only the following cast in `TRY/CATCH cx_sy_move_cast_error`.
- `CATCH` only for class-based exceptions.
- `CHECK <driver> IS NOT INITIAL.` (or an `IF … IS INITIAL. RETURN.` guard) before **every** `FOR ALL ENTRIES`.
- Do not pre-filter a sorted table in the caller when the DAO `WHERE` already filters.
- After a method call with a `RETURNING` parameter assert on the returned value, never on `sy-subrc`.
- No `TYPE c LENGTH n` directly on method parameters — use named types from the payment engine area's types interface.
- No SQL outside DAO/repository classes. Constructors never read the database.
- Explicit field lists in every `SELECT` (no `SELECT *`), `@` host variables.
- Deliver complete files.

### Naming and length (enforced by abaplint `abaplint.json` and `tools/portable_checks.py`)

| Element | Convention | Example | Enforced by |
|---|---|---|---|
| Importing / exporting / changing / returning parameter | `I?_` / `E?_` / `C?_` / `R?_` + type letter (v value, s structure, t table, o object, r reference, x exception) | `iv_key`, `es_diagnostic`, `ct_lines`, `rt_findings` | `method_parameter_names` |
| Class attribute | static `G?_`, instance `M?_`, constant `GC_` (also local classes and interfaces) | `gv_memo_package`, `mt_rules`, `gc_switch_name` | `class_attribute_names` |
| Local data / constant / field symbol | `L?_`, `LC_`, `<L?_…>`; a caught exception is `lx_error` (a second one in the same method `lx_<meaning>`) | `lv_key`, `lc_max`, `<ls_line>` | `local_variable_names` |
| Type | `TY_` (structure / element), `TT_` (table) | `ty_rule`, `tt_rule` | `types_naming` |
| Local class | `LCL_` (helper), `LHC_` / `LSC_` (RAP handler / saver), `LTD_` (test double or test data builder), `LCX_` (exception), test class `LTC_` | `ltd_sap_dao`, `ltc_r05_lot_reason` | `local_class_naming` |
| Selection screen | `P_` parameter, `S_` select-option, `SC_` screen element | `p_feb`, `s_kukey` | `selection_screen_naming` |
| Object | class `ZCL_CD_` / `ZCX_CD_` / behaviour pool `ZBP_`, interface `ZIF_CD_`, program / table / message class `Z…` | `ZCL_CD_EBS_ENGINE` | `object_naming` |
| Method | snake_case, never a data prefix (`lv_`, `it_`, `mo_`, `gc_` …; predicates `is_…` allowed), ≤ 30 incl. test methods | `validate_package`, `is_allowed` | `method_names` (portable) |
| Lengths (SAP) | objects, CDS entities, DDLS / SRVD / DCLS, methods, attributes, types, local classes, local data ≤ 30; **transparent tables ≤ 16**; message class ≤ 20; table fields ≤ 30; short texts ≤ 60 | `ZCD_OPS_ALRULE` (14) | `name_lengths`, `short_text_max_60` (portable) |

### Modern syntax (enforced by abaplint `abaplint.json`)

`INSERT … INTO TABLE` instead of `APPEND` (`prefer_insert_into_table`), string templates instead of `&&` with literals — a long template is split into `|…| && |…|` lines, an embedded expression may span lines (`prefer_string_template`), `RAISE EXCEPTION NEW` (`prefer_raise_exception_new`), `IS NOT` / `NP` instead of `NOT … IS` / `NOT … CP` (`prefer_is_not`), `CASE` instead of `IF / ELSEIF` on one operand (`change_if_to_case`), inline `CAST …( )->method( )` for a single-use cast helper (`prefer_inline_cast`), `RETURNING` instead of a single `EXPORTING` parameter (`prefer_returning_to_exporting`), no `RETURN` as last statement, no chaining of a single declaration, no `RECEIVING`, `xsdbool( )`, `line_exists( )`, `CORRESPONDING`, functional calls, strict SQL, no `SELECT *` / `ENDSELECT`, no needless copies / loop guards / boolean-via-IF / leading zeros in literals / SQL value conversion / pragmas, class-based exceptions. Mechanical fixes are reproducible: `python3 tools/modernize.py --abaplint <binary>` (table renames above 16 characters, `lx` → `lx_error`, `LCL_` test helpers → `LTD_`, the safe abaplint quick fixes) — idempotent, re-run after every merge.

**Left off on purpose:** `prefer_inline` — its quick fix turns typed declarations (`DATA lv_amount TYPE ty_amount`) into inferred calculation types (9 syntax errors in 72 fixes, rounding / type changes in amount arithmetic); declare inline where the expression already has the wanted type. `single_use_expression_temp` — its fixes nest whole DAO reads into calls (HCK checks) and fold named conditions (`lv_technical`, `lv_same`) and test expectations (`lt_exp`, given / when / then shape of §2 Unit tests) into one statement; a named intermediate that explains is kept (Clean ABAP). `omit_parameter_name` — explicit names on one-parameter calls are house style for readability. `select_single_full_key` (base config) — stays in the ATC-equivalent set, where the documented exemptions live. `prefer_abap_bool` — `abap_bool` is already used for every flag; `boolean` / `xfeld` DDIC fields stay as delivered.

### Unit tests
- `FOR TESTING RISK LEVEL HARMLESS DURATION SHORT` on every test class.
- Business logic: local `LTD_*` test doubles injected through the payment engine area injector (`ZCL_CD_<MOD>_INJECTOR`) and the core injector `ZCL_CD_OPS_INJECTOR`; `teardown` calls the injectors' `reset( )`.
- DAO tests: `cl_osql_test_environment` — create in `class_setup`, `clear_doubles` in `setup`, `destroy` in `class_teardown`.
- Build test data with **individual field assignment**, not inline `VALUE #( … )` (type resolution inside the osql environment).
- Wrap test method bodies in `TRY … CATCH cx_root` (except setup/teardown and methods that test exceptions) and fail with a message in the catch.
- Shape: a `ty_flags` struct for scenario intent, one `configure_scenario` helper, one act helper that gets the CUT from the factory, assertions with `assert_equals` and a `msg` on every assertion, constants instead of literals.
- `cl_abap_testdouble`: interface names lowercase; `set_parameter` only on EXPORTING/CHANGING/RETURNING; never guess a signature.
- Test through the public seam; no `LOCAL FRIENDS` when `run( )` reaches the behaviour.
- Every class has a test path: its own test include, or a row in `tools/test_path_register.csv` naming the covering test include or an exemption with its reason (partial exemptions of an own include are rows too). `docs/Coverage_Run_Register.csv` is generated from it (one row per class). Portable checks `test_path_every_class`, `osql_doubles_complete` (every table the tested DAO methods read is doubled) and `no_real_dao_in_tests` (`tools/test_checks.py`).
- Kernel / SAP API calls (AUTHORITY-CHECK, ENQUEUE, BAL, BCS, CTS, calendar FMs, bgPF) are tested through a `TEST-SEAM` around the call only; the production code keeps return codes and caught exceptions in local variables so that the `TEST-INJECTION` sets locals (never SY fields, never a RAISE). Each seam is named in the class's modification log.
- Coverage target ≥ 90 % (engine-redesign) — requirements baseline minimum 85 %. Assert absence of side effects (no save, no commit, no alert) where relevant.

## 3. Architecture

```
interfaces (types) → domain (engines, rules, checks: no SQL) → repositories (DAO: all SQL) → application (engine run) → presentation (report / CDS)
```

- **Core** (`src/core`): `ZIF_CD_OPS_TYPES` (finding, run, severity, RAG, action), `ZCX_CD_OPS_ERROR` (T100 class ZCD_OPS), `ZIF_CD_OPS_STORE` (run + findings), `ZIF_CD_OPS_PARAMS` (parameters) with its one implementation `ZCL_CD_OPS_PARAMS_CA` (adapter over the global framework `ZCA_PARAM`), `ZCL_CD_OPS_PARAM_SEED` (delivered definitions, generated; in-memory parameters of the unit tests), `ZIF_CD_OPS_ALERT`, `ZIF_CD_OPS_CLOCK`, `ZCL_CD_OPS_FACTORY` / `ZCL_CD_OPS_INJECTOR`, `ZCL_CD_OPS_UTIL`.
- Each payment engine area owns `ZIF_CD_<MOD>_TYPES`, its DAO interface(s), `ZCL_CD_<MOD>_FACTORY` (`GLOBAL FRIENDS zcl_cd_<mod>_injector`, getters `COND #( WHEN go_x_double IS BOUND THEN go_x_double ELSE NEW real( ) )`) and `ZCL_CD_<MOD>_INJECTOR` with `reset( )`.
- Plug-ins (rules, checks, adapters) are configured by class name and created with `zcl_cd_ops_factory=>get_plugin( )`, then `CAST` to the payment engine area interface in `TRY/CATCH cx_sy_move_cast_error`.
- Every payment engine area writes results only through `zcl_cd_ops_factory=>get_store( )` → one auditable store (ZCD_OPS_RUN / ZCD_OPS_FINDING). Findings of severity B/E/W become owned exceptions with an SLA due date.
- **Parameters live in the global framework `ZCA_PARAM`** (areas `CD_OPS`, `CD_EBS`, `CD_FMON`, `CD_HCK`; `param-framework/`). Read them only through `zcl_cd_ops_factory=>get_params( )->get_param( iv_name = zif_cd_<area>_types=>gc_param-xyz iv_default = zif_cd_<area>_types=>gc_param_default-xyz )` (`get_range` for select-option style rows; empty = not configured, never "all") — never hard-code thresholds, e-mail addresses, company codes, status literals, never read `ZCA_PARAM_*` tables or `ZIF_CA_PARAM` directly (exception: the configuration check `PARAM_INVALID`). **Every parameter name and delivered default is a constant** in the area's types interface (`gc_param`, `gc_param_default`; names completed at run time such as `HCK_MAX_AGE_H_<area>`, `RETENTION_DAYS_<target>`, `SLA_DAYS_<area>_<severity>`, `ALERT_<route>`, `EBS_PARSER_<format>` start with a `gc_param_prefix` constant). Integer parameters are read with the one helper `ZCL_CD_OPS_UTIL=>PARAM_INT( io_params iv_name iv_default )`.
- **Adapter rules (`ZCL_CD_OPS_PARAMS_CA`).** The area comes from the name prefix (`ALERT_ SLA_ RETENTION_ PURGE_ TRACE_` → `CD_OPS`, `EBS_` → `CD_EBS`, `FMON_` → `CD_FMON`, `HCK_` → `CD_HCK`; constants `GC_PARAM_AREA` / `GC_PARAM_AREA_PREFIX`). A value the framework resolves — maintained value or **definition default** — wins over the caller's `iv_default` (one source of defaults: the definition); a **BOOL** is `X` or blank, and a value row with blank value is **off** (a flag is never switched off with `N`). The caller's `iv_default` applies only when nothing resolves (no row, no definition default — fallback chains such as `ALERT_<route>` → `ALERT_DEFAULT`) or when the framework raises `ZCX_CA_PARAM` (unknown name, invalid value, mandatory missing): that error is never silent — listed once per snapshot by `get_errors( )` and shown by the next morning report as `PARAM_INVALID` (no SLG1 entry per run). `refresh_params` = `refresh( )` (start_run, A64). The `gc_param_default` constants stay: they are the fallback on a framework error and the delivered defaults the check compares.
- **Application log (SLG1) — minimum (user decision 2026-11-07).** Do not write SLG1 per run, per finding or per parameter read. Findings belong in `ZCD_OPS_FINDING`, alert attempts in `ZCD_OPS_ALLOG`, configuration errors in a morning-report check. SLG1 only through the APPLOG alert channel when a rule explicitly asks for it (digest, E or higher).
- **Adding a parameter:** (1) a `gc_param` constant (and its `gc_param_default`) in the area's types interface, read through `get_params( )`; a run-time name also adds its parts to `RUNTIME` in `tools/param_definitions.py`; (2) a row in `config/param_definitions.csv` (value type from the reading code: `PARAM_INT` → INT with MIN / MAX where obvious, flags → BOOL, comma lists → LIST, patterns → PCRE, class names → CLASS with the required interface, field / table names developer-owned; `DEFAULT_VALUE` = the constant; MANDATORY where the code cannot work without it); (3) `python3 tools/param_definitions.py` regenerates `ZCL_CD_OPS_PARAM_SEED`; the portable check `param_definitions_complete` fails until constant, definition, default and value type agree; (4) the definition goes to DV1 in the framework app on a customizing request (`Implementation_Order.md`).
- **Parameters in unit tests.** Unit tests never hand-write parameter logic: `DATA(lo_params) = NEW zcl_cd_ops_param_seed( )` (in-memory `ZCL_CA_PARAM_DAO_MEM` with every delivered definition), `lo_params->set( iv_name iv_value )` for a value row, `zcl_cd_ops_injector=>inject_params( lo_params->params( ) )` — the code under test runs the real framework semantics (`ZCL_CA_PARAM`) and its errors are kept in memory (`lo_params->logged( )`). Framework-level cases (own definitions, `ZCL_CA_PARAM_BUILDER`, `ZCL_CA_PARAM_INJECTOR=>INJECT_DAO`) are in the adapter's test class. A store double never serves parameters.
- Registry lookups fall back to a blank/`*` default row (a new source/bank/LOB costs configuration only).
- Configuration is maintained only through the four RAP configuration apps (`RAP_Config_Apps.md`); SM30 maintenance views are not delivered. New customizing table → add it to the spec in `tools/rap_generate.py`, add the three admin fields, regenerate.
- **New configuration rows only by transport (user decision 2026-11-07, design D-3):** every customizing table — also deadlines, SLAs, calendar rows and alert rules — gets new rows only in DV1 on a customizing request (DV1 → QA1 → PS4); production may edit existing rows (change-logged), never create or delete. There is no per-table exception in the policy, the gate or the generator. A table whose rows production must be able to switch off carries an `ACTIVE` flag that every reader filters (ZCD_FMON_DEADL, ZCD_FMON_SLA, ZCD_FMON_CAL, ZCD_OPS_ALRULE).
- **No application log for new rules / checks (user rule 2026-11-07):** SLG1 is kept to a minimum — new checks, adapters and policies write findings (ZCD_OPS_FINDING) only; alerts go by e-mail rules to SO23 lists; seeds never add an APPLOG alert rule.
- A failing plug-in never aborts a run: catch `zcx_cd_ops_error` and `cx_root` per plug-in and record a finding (`check_code = 'PLUGIN_ERROR'`, severity E).
- **Fail closed:** an EBS rule that raises is a PLUGIN_ERROR finding with action BLOCK and its lines count as unevaluated, never passed; a missing or unusable required rule is a configuration finding (A03).
- **Read-only towards production (user decision 2026-11-07):** the suite reads FS-CD / FI data and writes only its own tables (runs, findings, exception history, suppressions, file registry, PRISM evidence). No posting gate, line release, reprocessing navigation or outbound call; such a capability is a later phase with its own design.
- **Durable before notified:** commit the run header at start; commit results and run end before any alert or mail (a channel may `COMMIT WORK` itself); never commit a half-written save — `store->rollback( )`.

### Message class ZCD_OPS ranges
001–099 / 700–799 core · 100–199 / 500–599 EBS · 200–299 / 600–649 FMON · 300–399 / 650–699 HCK · 400–449 configuration apps. Every message is listed in `config/zcd_ops_messages.md` (the serializer writes the message class from it).

### No hardcoding (phase 5)
- **Regular expressions: PCRE only** (`pcre =` in `matches( )` / `find( )` / `replace( )` / `count( )`, `FIND|REPLACE … PCRE`, `CL_ABAP_REGEX=>CREATE_PCRE`, `replace_regexpr( pcre => … )` in CDS). POSIX (`regex =`, `FIND|REPLACE … REGEX`, `CL_ABAP_REGEX=>CREATE_POSIX`) is obsolete since ABAP 7.55 and fails the portable check `pcre_only`. Patterns in code are named constants, never built from input.
- **Patterns are PCRE matched to the complete value (user decision 2026-11-06).** Every configured or internal pattern — EBS flow patterns (ZCD_EBS_FLOW_PAT), FMON interface file names (ZCD_FMON_IFACE-NAME_PATTERN), HCK job names (ZCD_JOB_STEP-JOBNAME, job / log-object / cycle lists in ZCD_HCK_DEF parameters), suppression keys (ZCD_HCK_SUPPRESS-KEY_PATTERN), alert rule patterns (ZCD_OPS_ALRULE), the BAI issuer and CAMT receiver path constants — is PCRE, matched with `ZCL_CD_OPS_UTIL=>PCRE_MATCH` (`matches( val = … pcre = … case = abap_false )`: the **whole value** must match, never a partial find; **case ignored**, as the former `CP` wildcards). Blank keeps its meaning at each place (alert / suppression: any; flow / file name: not resolved by pattern). Specificity (FMON: most specific row wins) = literal characters, `ZCL_CD_OPS_UTIL=>PCRE_LITERALS`.
- **Validated on save and at runtime — an invalid pattern is never 'no match'.** One helper, `ZCL_CD_OPS_UTIL=>PCRE_VALID` (`CL_ABAP_REGEX=>CREATE_PCRE( … ignore_case = abap_true )`), behind: the configuration apps (generator check `('pcre', field)`, message 418), the suppression app (`ZCL_CD_HCK_SUPPRESSION=>CHECK_REQUEST`), the runtime configuration load (EBS FLOW_PATTERN_INVALID blocks the line, FMON PATTERN_INVALID, HCK E373 / PATTERN_INVALID / SUPPRESSION_PATTERN_INVALID, alert rule logged failed with 742), and the pattern check / migration reports.
- **No `CP` / `NP` in code**: no `CP` / `NP` comparison and no `option = 'CP'` range row (portable check `no_cp_patterns`). SQL never receives a pattern: ABAP SQL `LIKE_REGEXPR` is not parsed by the offline lint and cannot use an index, so the DAO reads by the non-pattern bounds (date window, status, day; distinct names first) and filters with `PCRE_MATCH` (`Performance_Review.md` §6b).
- **Check before activating:** `ZCD_OPS_PATTERN_CHECK` lists, for a pattern area and date window, every real value and the pattern(s) that capture it, values no pattern captures and patterns that capture nothing (`Operations_Runbook.md` §5e).
- **No user-facing text as a literal.** A text a user reads is a ZCD_OPS message, built only with `zcl_cd_ops_util=>text( iv_msgno = zif_cd_<area>_types=>gc_msg-<name> iv_v1 … iv_v4 [iv_tail] )` (long values such as exception texts go into `iv_tail`, never into a 50-character message variable), or a text symbol of the program / class (`TEXT-nnn`, source `docs/text_elements/<object>.texts.md`, serialized into the abapGit TPOOL).
- **No technical value as a literal** outside declarations: check codes, parameter names and defaults, statuses, keywords, prefixes, patterns are named constants in the area's types interface (or class constants), parameters in ZCA_PARAM, or customizing. SAP-defined values use SAP constants (e.g. `cl_abap_typedescr=>typekind_*`).
- Allowed exceptions are syntax or wire formats only, each listed with its reason in `tools/literal_allowlist.txt`.
- Guarded by `tools/portable_checks.py` (`no_inline_texts`, `message_constants_exist`); inventory in `docs/Hardcoding_Inventory.md`.
- **Nothing unused.** abaplint `unused_variables`, `unused_methods`, `unused_types`, `unused_ddic` (`abaplint.json`; RAP handler methods, draft tables and the lock table excluded by file pattern, `ATC_Validation.md` §4) and the portable checks `messages_used` (every ZCD_OPS message is raised by production code), `params_used` (every `gc_param` / `gc_param_prefix` constant is read by production code), `param_definitions_complete` (every name read has a definition and every definition is read, `tools/param_definitions.py`) and `constants_used` (every types-interface constant is referenced by code, a test or CDS — message numbers, check codes, parameter names and defaults one by one, other structures as value domains; a mention in documentation does not count), `tools/usage_checks.py`. Remove what they report together with its tests, messages and documentation.
- **CDS literals have one ABAP source.** CDS cannot read ABAP constants or parameters, so a fact a CDS view must hold as a literal (XBLNR bank-text PCRE and account length, dashboard date windows `gc_dashboard-window_days` / `gc_trx_dashboard`, credit indicator, reversal reason `gc_reversal_augrd`, completed run statuses, stale-threshold fallbacks) is declared once as a named ABAP constant and compared by the portable check `cds_abap_parity` (`tools/cds_abap_parity.py`, one row per fact in `PAIRS`: CDS file, regex, ABAP file, constant). A new CDS literal of this kind adds a row; drift fails the check.

### DDIC
Tables as ADT DDL source in `ddic/<pe_area>/<name>.tabl.ddl`. Delivery class C for customizing (SM30), A for application data. Note required secondary indexes in a comment.

## 4. Verification

Lint (offline, no SAP system): from `ops-suite/` run
`npx @abaplint/cli@2.120.92`
The config pins v758-compatible syntax and pulls SAP stubs from `abaplint/deps`. SAP objects missing there are stubbed in `ops-suite/lint_stubs/` (second, local dependency of `abaplint.json` and `abaplint.atc.json`; outside `src/`, so abapGit never pulls them): today only `IF_BGMC_OP_SINGLE_TX_UNCONTR` (bgPF, PRISM status API). The parameter framework `ZCA_PARAM` (`ZIF_CA_PARAM`, `ZCL_CA_PARAM_FACTORY`, test support `ZCL_CA_PARAM_DAO_MEM` / `_BUILDER` / `_INJECTOR`) is a third dependency read from its own sources `../param-framework/src` (no copy): the suite is linted against the real framework objects, which are never reported as suite issues; the framework has its own lint and checks (`param-framework/abaplint.json`, `tools/checks.py`). The portable checks scan `ops-suite/src` only. A stub is a lint aid, never evidence that the SAP object exists — each is a VERIFY-ADT item. A clean lint proves syntax and typing against stubs only — **not** activation, DDIC existence or ABAP Unit execution. Say so in every hand-over.

## 5. TDD and artefact headers (house approach)

> **First principle:** if something is hard to test, it is in the wrong layer.
> **Analogy:** a recipe is tasted at each step, not only when the dish is served.

- **Red → Green → Refactor.** Write the failing test first, in the test class that owns the behaviour, named after the **rule** (`unmapped_btc_always_blocks`, not `test_resolve_1`). If the rule cannot be named as a test, it is not clear enough to implement.
- **Test levels — use the cheapest that can prove it:**

| Level | Covers | Isolation | Cost |
|---|---|---|---|
| Domain | rules, resolvers, policies, statistics, renderers | none (pure logic, structures built field by field) | free |
| Application | engines: orchestration, persistence calls, alerts, circuit breaker | `LTD_*` doubles through the injectors | free |
| OSQL | DAO SQL: filters, keys, ordering, idempotency | `cl_osql_test_environment` | cheap |
| Integration | thin wrappers over SAP standard (FMs, BCS, ENQUEUE) | `RISK LEVEL DANGEROUS`, QA1 only, TVARVC-gated | manual |

- **Legacy parity:** every behaviour difference against the legacy validators is a row in `docs/Legacy_Parity_Comparison.md` in the same change. A green test that silently diverges from production is worse than a red one.
- One behaviour per test; assert the returned table, not one field; no test depends on another test's data; never weaken a test to make a change pass.
- Deliberately untested objects are listed with reason and alternative coverage in `docs/TDD_Approach_and_Coverage.md`.

Every ABAP source starts with the artefact header (SE24 short text stays ≤ 60 characters in the ABAP Doc line):

```
*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_engine.clas.abap
*& Purpose:
*& <what it does / what it does not do>
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*&---------------------------------------------------------------------*
```
Test includes end the purpose with "does not prove live SAP runtime behavior."

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
- More confirmed facts (full list and sources: `USAA_Known_Tables.md` §1):
  - Request → open item: ZCD_PAYM_REQ_LOG FIN number = DFKKOP-ZZ_FIN_TRANS_NUM; request → partner: ZZ_MEMBER_NO = BUT000-BPEXT, read **with** SOURCE first, then without (legacy PCLM partners).
  - ZCD_SPE_EXCP_LOG: every payment-request failure needs an SPE row, or the hourly status job never reports it.
  - Cheque status domain ZECT_STATUS: 3 failed, 4 rejected, 9 returned are terminal; mailed 10 → returned 9 allowed; otherwise higher may overwrite lower, never the reverse.
  - PCLM cancellation: CANCELLED = money will not leave; a paid request must never be left CANCELLED.
  - DPAYH-ZZ_PAYMENT_STATUS is the live payment status; DFKKOP-ZZ_BILLPLANID sits on DFKKOP (no DFKKNRK join).
  - FEBEP-BUDAT is always filled; FEBEP-XBLNR is never blank for BAI 452. BAI 143 / 452 are known unmapped codes (R14 blocks them until Treasury confirms a mapping).
  - TFK033D wildcard `*` does not work (enumerate); TVARVC refuses two type-P rows with the same name.
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

### Unit tests
- `FOR TESTING RISK LEVEL HARMLESS DURATION SHORT` on every test class.
- Business logic: local `LTD_*` test doubles injected through the payment engine area injector (`ZCL_CD_<MOD>_INJECTOR`) and the core injector `ZCL_CD_OPS_INJECTOR`; `teardown` calls the injectors' `reset( )`.
- DAO tests: `cl_osql_test_environment` — create in `class_setup`, `clear_doubles` in `setup`, `destroy` in `class_teardown`.
- Build test data with **individual field assignment**, not inline `VALUE #( … )` (type resolution inside the osql environment).
- Wrap test method bodies in `TRY … CATCH cx_root` (except setup/teardown and methods that test exceptions) and fail with a message in the catch.
- Shape: a `ty_flags` struct for scenario intent, one `configure_scenario` helper, one act helper that gets the CUT from the factory, assertions with `assert_equals` and a `msg` on every assertion, constants instead of literals.
- `cl_abap_testdouble`: interface names lowercase; `set_parameter` only on EXPORTING/CHANGING/RETURNING; never guess a signature.
- Test through the public seam; no `LOCAL FRIENDS` when `run( )` reaches the behaviour.
- Coverage target ≥ 90 % (engine-redesign) — master prompt minimum 85 %. Assert absence of side effects (no save, no commit, no alert) where relevant.

## 3. Architecture

```
interfaces (types) → domain (engines, rules, checks: no SQL) → repositories (DAO: all SQL) → application (engine run) → presentation (report / CDS)
```

- **Core** (`src/core`): `ZIF_CD_OPS_TYPES` (finding, run, severity, RAG, action), `ZCX_CD_OPS_ERROR` (T100 class ZCD_OPS), `ZIF_CD_OPS_STORE` (run + findings + params), `ZIF_CD_OPS_ALERT`, `ZIF_CD_OPS_CLOCK`, `ZCL_CD_OPS_FACTORY` / `ZCL_CD_OPS_INJECTOR`, `ZCL_CD_OPS_UTIL`.
- Each payment engine area owns `ZIF_CD_<MOD>_TYPES`, its DAO interface(s), `ZCL_CD_<MOD>_FACTORY` (`GLOBAL FRIENDS zcl_cd_<mod>_injector`, getters `COND #( WHEN go_x_double IS BOUND THEN go_x_double ELSE NEW real( ) )`) and `ZCL_CD_<MOD>_INJECTOR` with `reset( )`.
- Plug-ins (rules, checks, adapters) are configured by class name and created with `zcl_cd_ops_factory=>get_plugin( )`, then `CAST` to the payment engine area interface in `TRY/CATCH cx_sy_move_cast_error`.
- Every payment engine area writes results only through `zcl_cd_ops_factory=>get_store( )` → one auditable store (ZCD_OPS_RUN / ZCD_OPS_FINDING). Findings of severity B/E/W become owned exceptions with an SLA due date.
- Parameters: `store->get_param( iv_name = 'XYZ' iv_default = `...` )` — never hard-code thresholds, e-mail addresses, company codes, status literals.
- Registry lookups fall back to a blank/`*` default row (a new source/bank/LOB costs configuration only).
- Configuration is maintained only through the four RAP configuration apps (`RAP_Config_Apps.md`); SM30 maintenance views are not delivered. New customizing table → add it to the spec in `tools/rap_generate.py`, add the three admin fields, regenerate.
- A failing plug-in never aborts a run: catch `zcx_cd_ops_error` and `cx_root` per plug-in and record a finding (`check_code = 'PLUGIN_ERROR'`, severity E).
- **Fail closed where a check gates money:** an EBS rule that fails carries action BLOCK, so posting is blocked in enforce mode; `validate_for_posting` never raises (VALIDATION_ERROR, action BLOCK).
- **Durable before notified:** commit the run header at start; commit results and run end before any alert or mail (a channel may `COMMIT WORK` itself); never commit a half-written save — `store->rollback( )`.

### Message class ZCD_OPS ranges
001–099 / 700–799 core · 100–199 / 500–599 EBS · 200–299 / 600–649 FMON · 300–399 / 650–699 HCK · 400–449 configuration apps. Every message is listed in `config/zcd_ops_messages.md` (the serializer writes the message class from it).

### No hardcoding (phase 5)
- **No user-facing text as a literal.** A text a user reads is a ZCD_OPS message, built only with `zcl_cd_ops_util=>text( iv_msgno = zif_cd_<area>_types=>gc_msg-<name> iv_v1 … iv_v4 [iv_tail] )` (long values such as exception texts go into `iv_tail`, never into a 50-character message variable), or a text symbol of the program / class (`TEXT-nnn`, source `docs/text_elements/<object>.texts.md`, serialized into the abapGit TPOOL).
- **No technical value as a literal** outside declarations: check codes, parameter names and defaults, statuses, keywords, prefixes, patterns are named constants in the area's types interface (or class constants), parameters in ZCD_OPS_PARAM, or customizing. SAP-defined values use SAP constants (e.g. `cl_abap_typedescr=>typekind_*`).
- Allowed exceptions are syntax or wire formats only, each listed with its reason in `tools/literal_allowlist.txt`.
- Guarded by `tools/portable_checks.py` (`no_inline_texts`, `message_constants_exist`); inventory in `docs/Hardcoding_Inventory.md`.

### DDIC
Tables as ADT DDL source in `ddic/<pe_area>/<name>.tabl.ddl`. Delivery class C for customizing (SM30), A for application data. Note required secondary indexes in a comment.

## 4. Verification

Lint (offline, no SAP system): from `ops-suite/` run
`/tmp/claude-0/-home-user-bai/914e445a-1a4a-59f8-9715-e9953e835f40/scratchpad/lint/node_modules/.bin/abaplint`
The config pins v758-compatible syntax and pulls SAP stubs from `abaplint/deps`. A clean lint proves syntax and typing against stubs only — **not** activation, DDIC existence or ABAP Unit execution. Say so in every hand-over.

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

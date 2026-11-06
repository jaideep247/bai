# ATC validation — offline evidence and what DV1 must still confirm

> **First principle:** ATC runs inside the SAP system; offline we can prove everything that does not need the system, and name exactly what does.
> **Analogy:** a pre-flight checklist done in the hangar — instruments that only work in the air (system-dependent checks) are tested on the first flight (DV1 ATC run), not assumed.

## 1. How it is checked

| Layer | Tool | Config | Result (2026-11-06) |
|---|---|---|---|
| Syntax, typing, house rules | abaplint 2.x, ABAP 7.58, SAP stubs (`abaplint/deps`) and the suite's own abapGit table/message definitions | `ops-suite/abaplint.json` | **0 issues / 309 files** |
| ATC-equivalent checks | abaplint rules mapped to SAP Code Inspector / SLIN / security / DDIC checks | `ops-suite/abaplint.atc.json` | **2 findings = 2 documented exemptions** (§4) |
| House rules not in abaplint | `tools/portable_checks.py` | — | 13/13 checks passed |
| Continuous | GitHub Actions `.github/workflows/abaplint.yml` | both configs on every push | fails on any new finding |

## 2. ATC check categories covered offline

| ATC / Code Inspector area | abaplint rule(s) |
|---|---|
| Syntax check, extended program check (SLIN) | `check_syntax`, `parser_error`, `unused_variables`, `unused_types`, `unused_methods`, `unreachable_code`, `empty_statement`, `identical_conditions`, `constant_condition`, `uncaught_exception`, `implement_methods`, `method_implemented_twice`, `superclass_final`, `check_abstract` |
| Text elements / selection texts (SLIN) | `check_text_elements`, `selection_screen_texts_missing` (texts delivered in the abapGit program XML) |
| Messages (SLIN MESSAGE check) | `message_exists`, `msag_consistency` (message class ZCD_OPS in abapGit) |
| Robust programming — sy-subrc after SELECT SINGLE, READ TABLE, AUTHORITY-CHECK, OPEN DATASET, ASSIGN, DB writes | `check_subrc` |
| Performance — SELECT *, ENDSELECT, DB in loop, SELECT SINGLE without full key, SELECT without ORDER BY (HANA), SORT on keyless table, DELETE in LOOP | `select_performance`, `db_operation_in_loop`, `select_single_full_key`, `select_add_order_by`, `sort_empty_key`, `delete_index_in_loop` |
| Security — dynamic SQL, CALL TRANSACTION authority, kernel calls, modifying SAP tables, host-variable escaping, strict SQL | `dangerous_statement`, `call_transaction_authority_check`, `forbidden_kernel_write`, `modify_only_own_db_tables`, `sql_escape_host_variables`, `strict_sql` |
| DDIC — table definitions, enhancement category, abapGit XML consistency | `check_ddic`, `tabl_enhancement_category`, `xml_consistency`, `description_empty` |
| Obsolete statements, classic exceptions | `obsolete_statement`, `use_class_based_exceptions`, `classic_exceptions_overlap`, `try_without_catch`, `try_cast_empty_catch` |

## 3. Findings fixed in this validation (184 → 1)

| Finding | Count | Fix |
|---|---|---|
| abapGit table XML: INT4 internal type `I` instead of `X` | 30 | Generator corrected (`tools/abapgit_serialize.py`) — would have shown every table as changed on the first pull |
| Selection texts / text symbols missing | 42 | Text pools for the three reports in the program XML (from `docs/text_elements/`) |
| SELECT without ORDER BY (incl. **UP TO n ROWS** on TBTCO, grouped aggregate, legacy-table read — non-deterministic on HANA) | 13 | ORDER BY added |
| sy-subrc not handled after READ TABLE / INSERT | 12 | `VALUE #( … OPTIONAL )`; **two were latent bugs** in `ZCL_CD_FMON_ENGINE` (READ TABLE INTO inside a loop kept the previous row's values when the key was not found) |
| FOR ALL ENTRIES guard not in house form | 10 | `CHECK <table> IS NOT INITIAL.` (abap-standards) |
| SELECT SINGLE without full key | 5 | Full key or `UP TO 1 ROWS` with ORDER BY; client field renamed `MANDT` (classic convention) |
| SORT / DELETE ADJACENT DUPLICATES on keyless table | 4 | `BY table_line` / `COMPARING table_line` |
| Message 000 called with 1 of 4 parameters | 1 | Four parameters |
| Unused type | 1 | Removed |

## 4. Documented exemptions (request as ATC exemptions in DV1)

| Object | Check | Justification |
|---|---|---|
| `ZCL_CD_HCK_DAO=>EXECUTE_AGGREGATE` (line 176) | SELECT without ORDER BY | Aggregate without GROUP BY returns exactly one row; pseudo comment `"#EC CI_NOORDER` set (honoured by ATC; abaplint's rule ignores pseudo comments) |
| `ZCL_CD_OPS_ALERT_DAO=>INSERT_LOG` | sy-subrc after INSERT … ACCEPTING DUPLICATE KEYS | Duplicate audit keys are skipped on purpose; `"#EC CI_SUBRC` set |
| `ZBP_R_CD_*` behaviour pools | `check_abstract`, `unused_methods` | ABAP requires `ABSTRACT FINAL … FOR BEHAVIOR OF`; handler methods are called by the RAP framework. Excluded by file pattern in `abaplint.atc.json`; real ATC does not report these |
| `ZCL_CD_FMON_DAO=>INSERT_EVENT` and `SAVE_FILES` | Database operation in loop | INSERT_EVENT: bounded retry (3 attempts) only after a primary-key collision with a parallel writer. SAVE_FILES (audit A04): row lock + version compare per registry row, bounded by the files of one run. `"#EC CI_SEL_NESTED` set |
| `ZCL_CD_EBS_SAP_DAO`, `ZCL_CD_FMON_DAO`, `ZCL_CD_HCK_DAO` | Dynamic SQL (security / Code Vulnerability Analyzer) | Table and field names come only from customizing and are validated against the DDIC (and the whitelist ZCD_HCK_TABWL); values are bound host variables or escaped with `cl_abap_dyn_prg=>quote`; no user input reaches the statement. Excluded file-by-file in `abaplint.atc.json`, so new dynamic SQL anywhere else still fails |

## 5. What only the SAP system can confirm (run in DV1)

1. ATC with the company's check variant on packages `ZCD_OPS*`, and SAP's standard S/4HANA readiness and HANA performance variants if DV1 has them.
2. Code Vulnerability Analyzer, if licensed — the dynamic-SQL exemptions above.
3. Checks needing system data: package interface / use access, field existence of every `VERIFY-DDIC` field in standard and legacy tables (abaplint treats standard tables as unknown), function-payment engine area interfaces, authorization objects.
4. ABAP Unit with coverage (`Coverage_Run_Register.csv`).

## 6. DV1 checklist in ADT (Eclipse) — first import

| # | Step | How | Pass when | Suite-specific note |
|---|---|---|---|---|
| 1 | Import | abapGit pull into package `ZCD_OPS` with a workbench transport | All objects active, abapGit shows no local differences | Tables, message class and text pools come from the repository XML — do not create them by hand |
| 2 | DDIC facts | SE11 for every `VERIFY-DDIC` marker (list in the payment engine area READMEs) | Field exists with the expected type | A missing field is a code change, not an ATC exemption |
| 3 | ATC | Package `ZCD_OPS` (include subpackages) or the transport: *Run As > ABAP Test Cockpit With…* and choose the variant used on transport release; single object: Ctrl+Shift+F2 | 0 priority 1 and 2 findings without an approved exemption | Use the company's **classic** variant. `ABAP_CLOUD_DEVELOPMENT_DEFAULT` is for ABAP Cloud: this suite reads FEBEP, DFKK*, BSEG, TBTCO and uses `cl_bcs` on purpose (classic track), so that variant reports every unreleased API — run it only for information |
| 4 | Baseline / delta | ATC baseline | — | Every object in the suite is new, so every finding is ours; a baseline does not hide anything here |
| 5 | Exemptions | ATC Problems view: *Request Exemption* per finding, approver as per ATC setup | The three exemptions in §4 approved; no others | Never silence a finding with a quick fix that only adds a pseudo comment |
| 6 | Quick fixes (Ctrl+1) | Only for findings §3 does not explain | Each fix reviewed, unit tests still green, change committed back to git | A fix applied only in DV1 makes abapGit show the object as changed and is lost at the next pull — commit it through abapGit |
| 7 | Formatter (Shift+F1) | Optional | — | The code already uses upper-case keywords. Formatting with other team settings rewrites every object and creates a large diff with no functional change: if used, apply to all objects once and commit through abapGit |
| 8 | ABAP Unit | Package `ZCD_OPS`: Ctrl+Shift+F10; with coverage: Ctrl+Shift+F11 | 698 test methods, all green; statement coverage ≥ 85 % (target 90 %) | DAO tests use `cl_osql_test_environment` (no data changes); all test classes are RISK LEVEL HARMLESS, so the client setting for risk level does not skip any |
| 9 | Release gate | ATC check on transport release (central ATC setting, maintained by the ATC administrator) | Release blocked on priority 1/2 | An "ATC on activation" setting in ADT preferences was not confirmed by us — rely on the central release check |
| 10 | Evidence | Export the ATC result and the coverage figures | Recorded | `Coverage_Run_Register.csv`; `Test_and_Validation_Document.md` §14 |

**Status:** offline evidence complete; DV1 ATC and ABAP Unit pending. Record both in `Test_and_Validation_Document.md` §14.

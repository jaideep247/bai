# Review response — principal consultant review (2026-11-06)

> **First principle:** answer each finding against the code that ships, with evidence — agree where it is right, fix it the same day, and say plainly where it does not apply.
> **Analogy:** an audit close-out sheet — every observation gets a status, an owner and a reference, not a debate.

**Scope note.** The review was performed on the repository root documents and the empty `src` submodule — the **first framework** (`ZCL_CD_BANK_VAL_*`, scored 6.5/10). It did not cover `ops-suite/` (the consolidated suite). Each finding below is answered for `ops-suite/`; the first framework is archived in `legacy/` and is not transported.

| # | Finding | Applies to ops-suite? | Action / evidence |
|---|---|---|---|
| 1a | Dangling submodule gitlinks `src`, `abapGit` without `.gitmodules` → empty clone | **Yes (repo root)** | Gitlinks removed from the index; commits recorded in `legacy/README.md` |
| 1b | No `.abapgit.xml`, no package descriptors, abapGit cannot import | **Yes** | `/.abapgit.xml` (starting folder `/ops-suite/src/`, PREFIX logic), `package.devc.xml` per folder → `ZCD_OPS`, `ZCD_OPS_CORE/_EBS/_FMON/_HCK`; object XML for every class, interface, program; **30 tables as abapGit TABL XML**; message class `ZCD_OPS` as MSAG XML. Generator: `tools/abapgit_serialize.py`. Non-abapGit files moved out of `src` (`ops-suite/cds/`, `docs/text_elements/`) |
| 1c | 65 redundant root markdown files | **Yes (repo root)** | Moved to `legacy/framework_v1_docs/`; root has `README.md` + master prompt only |
| 3.1 | FEBEP keyed by BELNR/GJAHR instead of KUKEY/ESNUM | No | Lines are keyed `FEB<KUKEY>/<ESNUM>` (`ZCL_CD_EBS_SRC_FEB`, test `lines_keyed_to_statement`); findings by RUN_ID + FINDING_NO. BELNR is data only (rules R19/R20) |
| 3.2a | `SORTED … UNIQUE KEY` on DOC1R / SELW1 / ZTNUM / AUGBL → `ITAB_DUPLICATE_KEY` | No | Every DAO SELECT target is a STANDARD table; unique keys are used only for customizing primary keys, key lists built with `INSERT` (duplicates ignored, no dump) and hashed aggregates |
| 3.2b | ZTNUM unique only per house bank; DOC1R not unique in DPAYH | **Yes (latent)** | `TY_CHECK` carries HBKID/HKTID; R07C/R08/R12 use `checks_for_line( )` scoped to the statement's house bank account (test `r08_other_house_bank_ignored`). DPAYH read excludes proposal runs (`XVORL = space`, VERIFY-DDIC) and is ordered newest run first |
| 3.3 | Factory proliferation, duplicate `*_enh` classes, global test doubles | No | One factory + injector per module (4) as per house standard; no duplicate classes; all test doubles are local `LTD_*` classes in test includes; DAO tests use `cl_osql_test_environment` |
| 3.4 | Giant constants class, wrapping `abap_true` / `sy-subrc`, `TYPE string` constants | No | `abap_true`, `abap_false`, `sy-subrc` used directly; constants are domain values in each module's types interface, typed with named fixed-length types |
| 3.5a | Custom TTL cache instead of table buffering | **Partly** | Customizing tables now generated with **full buffering** (DD09L BUFALLOW/PUFFERUNG); application tables unbuffered. The store's parameter read and the engine's per-run configuration copy remain (one read per run, bounded) |
| 3.5b | Unbounded memory in long batch runs | **Yes (latent)** | EBS engine keeps at most `EBS_RESULT_MAX` findings in memory; counts and RAG cover all, every finding is saved per package (test `kept_findings_are_capped`). Lines kept for display were already capped |
| 3.6 | RAP LUW: `cl_bcs` / `BAL_DB_SAVE` in behaviour handlers; missing SRVD/SRVB | No RAP BO in the suite | Reports run in their own LUW; documented rule: the alert router and channels must never be called from RAP handlers (use bgPF). Analytics are read-only CDS analytical queries (no OData service binding needed for Multidimensional Reports) |
| 3.7 | Exceptions for business outcomes; exceptions collected in tables | No | Business failures are findings (rows with severity and action); `ZCX_CD_OPS_ERROR` only for technical failure (configuration unreadable, class missing, file unreadable). Rules contain no `RAISE` |

## Verification after the changes

- abaplint (7.58 rules, SAP stubs): 0 issues over 309 files, **now including the abapGit table definitions**, so every SELECT / INSERT on the ZCD_* tables is checked against its field list (proved by a deliberate typo that was caught, then reverted).
- ATC-equivalent rule set: 184 findings fixed down to 1 documented exemption — `ATC_Validation.md`.
- Portable checks: see `portable_checks.json`.
- Not verified: abapGit pull into DV1, activation, ABAP Unit run — first DV1 import is the test.

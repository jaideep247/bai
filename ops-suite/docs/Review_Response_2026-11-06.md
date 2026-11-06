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
| 3.3 | Factory proliferation, duplicate `*_enh` classes, global test doubles | No | One factory + injector per payment engine area (4) as per house standard; no duplicate classes; all test doubles are local `LTD_*` classes in test includes; DAO tests use `cl_osql_test_environment` |
| 3.4 | Giant constants class, wrapping `abap_true` / `sy-subrc`, `TYPE string` constants | No | `abap_true`, `abap_false`, `sy-subrc` used directly; constants are domain values in each payment engine area's types interface, typed with named fixed-length types |
| 3.5a | Custom TTL cache instead of table buffering | **Partly** | Customizing tables now generated with **full buffering** (DD09L BUFALLOW/PUFFERUNG); application tables unbuffered. The store's parameter read and the engine's per-run configuration copy remain (one read per run, bounded) |
| 3.5b | Unbounded memory in long batch runs | **Yes (latent)** | EBS engine keeps at most `EBS_RESULT_MAX` findings in memory; counts and RAG cover all, every finding is saved per package (test `kept_findings_are_capped`). Lines kept for display were already capped |
| 3.6 | RAP LUW: `cl_bcs` / `BAL_DB_SAVE` in behaviour handlers; missing SRVD/SRVB | No RAP BO in the suite | Reports run in their own LUW; documented rule: the alert router and channels must never be called from RAP handlers (use bgPF). Analytics are read-only CDS analytical queries (no OData service binding needed for Multidimensional Reports) |
| 3.7 | Exceptions for business outcomes; exceptions collected in tables | No | Business failures are findings (rows with severity and action); `ZCX_CD_OPS_ERROR` only for technical failure (configuration unreadable, class missing, file unreadable). Rules contain no `RAISE` |

## Verification after the changes

- abaplint (7.58 rules, SAP stubs): 0 issues over 309 files, **now including the abapGit table definitions**, so every SELECT / INSERT on the ZCD_* tables is checked against its field list (proved by a deliberate typo that was caught, then reverted).
- ATC-equivalent rule set: 184 findings fixed down to 1 documented exemption — `ATC_Validation.md`.
- Portable checks: see `portable_checks.json`.
- Not verified: abapGit pull into DV1, activation, ABAP Unit run — first DV1 import is the test.

---

# Part B — runtime audit of ops-suite (2026-11-06)

Second review, this time of `ops-suite` itself (engines and FMON DAO). Each finding was checked against the code before it was answered.

| Prio | Finding | Verdict | Fix | Test (written before the fix) |
|---|---|---|---|---|
| P0 | EBS: a rule that raises gives `PLUGIN_ERROR` with action NOTIFY; `must_block` blocks only on B / BLOCK → **posting allowed in enforce mode** | **Confirmed** | `PLUGIN_ERROR` carries action BLOCK. Also: `validate_for_posting` no longer raises — validation that cannot run at all (e.g. configuration unreadable) is a `VALIDATION_ERROR` finding with action BLOCK. Monitor mode unchanged | `failed_rule_blocks_posting`, `broken_config_blocks_posting` |
| P1 | FMON: `EVENT_NO = MAX + 1` — parallel writers take the same number | **Confirmed** | On sy-subrc 4 the business key is re-checked: recorded → idempotent; otherwise a new number, at most 3 attempts, then `ZCX_CD_OPS_ERROR` (message 010) | Collision not reproducible in one session — §5 of `TDD_Approach_and_Coverage.md`, QA1 parallel-run case |
| P1 | FMON: every failed INSERT treated as "duplicate" | **Confirmed** (sy-subrc 4 can be the primary key or the unique index SRC) | Same fix: the business key decides. Other database errors raise `CX_SY_OPEN_SQL_DB` and roll back the LUW (unchanged, correct) | As above |
| P1 | FMON: partial persistence | **Confirmed**, wider than reported: (a) the e-mail channel's own `COMMIT WORK` committed findings and registry before the run was finished; (b) files saved but events failed → the final commit wrote a half registry | Run header committed at start; registry failure → `rollback( )` (new store method) + `PERSIST_ERROR` finding; results and run end committed before alerts | `persist_error_rolls_back`, `alerts_sent_after_commit` |
| P2 | Alerts dispatched before the durable commit | **Confirmed in FMON and HCK** (EBS already committed first) | Commit, then dispatch; a dispatch failure is saved and committed separately. HCK now also commits its run header at start, so a run that dumps stays visible (status R) to the health-of-the-health-check | `alerts_sent_after_commit` (FMON, HCK) |
| P2 | `VALUE #( … OPTIONAL )` followed by `IF sy-subrc = 0` | **Confirmed — introduced in the ATC round** (table expressions do not set sy-subrc) | `READ TABLE … WITH TABLE KEY` + sy-subrc. Only occurrence in the suite | Lint rule; no behavioural test (the stale sy-subrc was 0 in practice) |

**Not done in this change (proposed, awaiting decision):**
- A durable alert outbox with retry. Today: alerts go out after the commit; failed deliveries are findings and appear in morning report category E.
- A run lock per payment engine area + variant, and carrying forward open exceptions across re-runs (owner and due date kept, auto-resolved when the item passes).

**Verification:** abaplint 0 issues / 309 files; ATC-equivalent set: 2 documented exemptions; portable checks 13/13; 321 unit test methods. None executed in SAP yet.

---

# Part C — EBS business-rule audit (2026-11-06)

| Prio | Finding | Verdict | Fix | Test (written before the fix) |
|---|---|---|---|---|
| High | R07 reads the first DPAYH row | **Confirmed** | Any productive run with an allowed status passes; the message lists every status found | `r07_any_run_with_status_ok` |
| High | R07L reads the first retrieval-log row | **Confirmed** (a failed attempt can follow a successful one, as in `ZCD_PAYM_REQ_LOG`) | Any attempt with an allowed status passes | `r07l_any_af_attempt_passes` |
| High | R07R reads the first returns-lot item | **Confirmed** | Any lot with an allowed status passes | `r07r_any_done_lot_passes` |
| — | (same pattern, found while fixing) R07C reads the first register row | **Confirmed** | Fails when **any** row is cancelled (fail closed) | `r07c_any_cancelled_row_fails` |
| High | R12 counts a check once although several register rows exist | **By design, now documented**: count = bank entries with at least one register row; total = all register rows (R08 sums them per check, parity D7). Legacy compared input lines with register rows over the whole run (D7) | Definition in the class and in parity D12 | `r12_code_total_mismatch` (existing) |
| Medium | House-bank filter accepts a missing HBKID on either side | **Confirmed for the statement side** (account missing from ZCD_EBS_ACCT: S04 reported it, but R07C / R08 / R12 still matched across banks). Register side: HBKID is part of the DFKKCR key (VERIFY-DDIC) | Statement without house bank matches only when all candidate rows are in one account; otherwise HOUSE_BANK_AMBIGUOUS | `r08_unknown_bank_ambiguous`, `r08_unknown_bank_single_ok` |
| Medium | R18 skips a statement without G/L account silently | **Confirmed** | GL_ACCOUNT_NOT_MAPPED finding | `r18_unmapped_gl_reported` |
| — | R09 misses duplicates split across packages | **Not confirmed**: a package holds whole statements (`ZCL_CD_EBS_SRC_FEB`, N statements per package) and the duplicate key contains the statement; a statement delivered twice is S07 | No change | `r09_second_identical_entry`, `s07_already_imported_fails` (existing) |

**Verification:** abaplint 0 issues; ATC-equivalent set: 2 documented exemptions; portable checks 13/13; 363 test methods on this branch before the phase 2 merge. Not executed in SAP.


---

# Part D — static repository audit A01–A105 (consolidated index)

The audit reviewed `main` at `8cdfdce`; all fixes below are on branch `claude/loving-albattani-qexsjc` (phase 6 merged 2026-11-06) and were taken to `main` afterwards. Per-finding verdict, fix, tests and residual risk: `Audit_Response_EBS.md`, `Audit_Response_FMON.md`, `Audit_Response_HCK_CORE.md`. Business decisions: `RAP_Apps_Design.md` (D-1…D-6) and `Release_Readiness.md` §3. Nothing here has been executed in SAP — gates in `Release_Readiness.md`.

| Finding | Status |
|---|---|
| A01 | Fixed: CI pinned to abaplint 2.120.92, report parameter typed (e9cc7ac); the divisor finding was a false positive of abaplint 2.120.19 |
| A02 | Deferred — the pre-posting path (BAdI FIEB_CHANGE_BS_DATA, enforce mode, blocked-line release) is switched off and not part of this release (EBS is a post-posting detective control); needs the SE18 signature in the future enforcement phase; contract documented in Release_Readiness.md |
| A03 | Fixed — see Audit_Response_EBS.md |
| A04 | Fixed — see Audit_Response_FMON.md |
| A05 | Fixed — see Audit_Response_FMON.md |
| A06 | Fixed — see Audit_Response_HCK_CORE.md |
| A07 | Fixed — see Audit_Response_EBS.md |
| A08 | Fixed — see Audit_Response_EBS.md |
| A09 | Fixed: any productive run with an allowed status passes, all statuses reported (d79e084) |
| A10 | Fixed: any matching record with an allowed status passes (d79e084) |
| A11 | Fixed — see Audit_Response_EBS.md |
| A12 | Not deployed (legacy / jaideep247/src reference) — recorded in Legacy_Parity_Comparison; used only as comparison baseline |
| A13 | Not deployed (legacy / jaideep247/src reference) — recorded in Legacy_Parity_Comparison; used only as comparison baseline |
| A14 | Fixed — see Audit_Response_EBS.md |
| A15 | Fixed: nearest predecessor by date and number; canonical account key in phase 6 (ac9cefb, A25) |
| A16 | Fixed: GL_ACCOUNT_NOT_MAPPED (d79e084); company/house-bank identity via A25 |
| A17 | Fixed — see Audit_Response_HCK_CORE.md |
| A18 | Fixed — see Audit_Response_HCK_CORE.md |
| A19 | Not deployed (legacy / jaideep247/src reference) — recorded in Legacy_Parity_Comparison; used only as comparison baseline |
| A20 | Not deployed (legacy / jaideep247/src reference) — recorded in Legacy_Parity_Comparison; used only as comparison baseline |
| A21 | Not deployed (legacy / jaideep247/src reference) — recorded in Legacy_Parity_Comparison; used only as comparison baseline |
| A22 | Fixed: ZCD_OPS authorisation (activity 16 per payment engine area) in all reports (phase 1, 463e88e) |
| A23 | Fixed: retention purge (phase 1) and exception app with four-eyes waivers (phase 3); retention decision 400 days |
| A24 | Fixed: ATC step requires exit 0/1, summary line, files and matching count (e9cc7ac) |
| A25 | Fixed — see Audit_Response_EBS.md |
| A26 | Fixed — see Audit_Response_EBS.md |
| A27 | Fixed — see Audit_Response_EBS.md |
| A28 | Fixed — see Audit_Response_EBS.md |
| A29 | Not deployed (legacy / jaideep247/src reference) — recorded in Legacy_Parity_Comparison; used only as comparison baseline |
| A30 | Not deployed (legacy / jaideep247/src reference) — recorded in Legacy_Parity_Comparison; used only as comparison baseline |
| A31 | Not deployed (legacy / jaideep247/src reference) — recorded in Legacy_Parity_Comparison; used only as comparison baseline |
| A32 | Fixed — see Audit_Response_EBS.md |
| A33 | Fixed — see Audit_Response_EBS.md |
| A34 | Fixed — see Audit_Response_EBS.md |
| A35 | Fixed — see Audit_Response_EBS.md |
| A36 | Not deployed (legacy / jaideep247/src reference) — recorded in Legacy_Parity_Comparison; used only as comparison baseline |
| A37 | Not deployed (legacy / jaideep247/src reference) — recorded in Legacy_Parity_Comparison; used only as comparison baseline |
| A38 | Fixed — see Audit_Response_FMON.md |
| A39 | Fixed — see Audit_Response_FMON.md |
| A40 | Fixed — see Audit_Response_FMON.md |
| A41 | Fixed — see Audit_Response_FMON.md |
| A42 | Fixed — see Audit_Response_HCK_CORE.md |
| A43 | Fixed — see Audit_Response_HCK_CORE.md |
| A44 | Fixed — see Audit_Response_HCK_CORE.md |
| A45 | Fixed — see Audit_Response_HCK_CORE.md |
| A46 | Fixed — see Audit_Response_HCK_CORE.md |
| A47 | Fixed — see Audit_Response_HCK_CORE.md |
| A48 | Fixed — see Audit_Response_HCK_CORE.md |
| A49 | Fixed — see Audit_Response_FMON.md |
| A50 | Fixed — see Audit_Response_FMON.md |
| A51 | Fixed — see Audit_Response_FMON.md |
| A52 | Fixed — see Audit_Response_FMON.md |
| A53 | Not deployed (legacy / jaideep247/src reference) — recorded in Legacy_Parity_Comparison; used only as comparison baseline |
| A54 | Not deployed (legacy / jaideep247/src reference) — recorded in Legacy_Parity_Comparison; used only as comparison baseline |
| A55 | Not deployed (legacy / jaideep247/src reference) — recorded in Legacy_Parity_Comparison; used only as comparison baseline |
| A56 | Fixed — see Audit_Response_HCK_CORE.md |
| A57 | Fixed — see Audit_Response_HCK_CORE.md |
| A58 | Fixed — see Audit_Response_HCK_CORE.md |
| A59 | Fixed — see Audit_Response_HCK_CORE.md |
| A60 | Fixed — see Audit_Response_HCK_CORE.md |
| A61 | Fixed — see Audit_Response_HCK_CORE.md |
| A62 | Fixed — see Audit_Response_EBS.md |
| A63 | Fixed — see Audit_Response_HCK_CORE.md |
| A64 | Fixed — see Audit_Response_EBS.md |
| A65 | Fixed — see Audit_Response_EBS.md |
| A66 | Fixed — see Audit_Response_EBS.md |
| A67 | Fixed — see Audit_Response_EBS.md |
| A68 | Fixed — see Audit_Response_EBS.md |
| A69 | Fixed — see Audit_Response_EBS.md |
| A70 | Not deployed (legacy / jaideep247/src reference) — recorded in Legacy_Parity_Comparison; used only as comparison baseline |
| A71 | Not deployed (legacy / jaideep247/src reference) — recorded in Legacy_Parity_Comparison; used only as comparison baseline |
| A72 | Not deployed (legacy / jaideep247/src reference) — recorded in Legacy_Parity_Comparison; used only as comparison baseline |
| A73 | Not deployed (legacy / jaideep247/src reference) — recorded in Legacy_Parity_Comparison; used only as comparison baseline |
| A74 | Not deployed (legacy / jaideep247/src reference) — recorded in Legacy_Parity_Comparison; used only as comparison baseline |
| A75 | Not deployed (legacy / jaideep247/src reference) — recorded in Legacy_Parity_Comparison; used only as comparison baseline |
| A76 | Not deployed (legacy / jaideep247/src reference) — recorded in Legacy_Parity_Comparison; used only as comparison baseline |
| A77 | Not deployed (legacy / jaideep247/src reference) — recorded in Legacy_Parity_Comparison; used only as comparison baseline |
| A78 | Not deployed (legacy / jaideep247/src reference) — recorded in Legacy_Parity_Comparison; used only as comparison baseline |
| A79 | Not deployed (legacy / jaideep247/src reference) — recorded in Legacy_Parity_Comparison; used only as comparison baseline |
| A80 | Not deployed (legacy / jaideep247/src reference) — recorded in Legacy_Parity_Comparison; used only as comparison baseline |
| A81 | Not deployed (legacy / jaideep247/src reference) — recorded in Legacy_Parity_Comparison; used only as comparison baseline |
| A82 | Not deployed (legacy / jaideep247/src reference) — recorded in Legacy_Parity_Comparison; used only as comparison baseline |
| A83 | Not deployed (legacy / jaideep247/src reference) — recorded in Legacy_Parity_Comparison; used only as comparison baseline |
| A84 | Not deployed (legacy / jaideep247/src reference) — recorded in Legacy_Parity_Comparison; used only as comparison baseline |
| A85 | Fixed — see Audit_Response_EBS.md |
| A86 | Fixed — see Audit_Response_EBS.md |
| A87 | Fixed — see Audit_Response_HCK_CORE.md |
| A88 | Fixed — see Audit_Response_HCK_CORE.md |
| A89 | Fixed — see Audit_Response_FMON.md |
| A90 | Fixed — see Audit_Response_FMON.md |
| A91 | Fixed — see Audit_Response_EBS.md |
| A92 | Fixed — see Audit_Response_EBS.md |
| A93 | Fixed — see Audit_Response_EBS.md |
| A94 | Fixed — see Audit_Response_EBS.md |
| A95 | Fixed — see Audit_Response_EBS.md |
| A96 | Fixed — see Audit_Response_EBS.md |
| A97 | Fixed — see Audit_Response_EBS.md |
| A98 | Fixed — see Audit_Response_EBS.md |
| A99 | Fixed: BCS result checked (A45); status S documented as submitted, SOST for delivery (3c7049b) |
| A100 | Fixed (later checkpoint) — FMON long file names: digest key verified against the full name (75d061e); see Audit_Response_FMON.md |
| A101 | Fixed in part before (A58), completed — HCK history per series incl. DIM2 (3e2dc31); see Audit_Response_HCK_CORE.md |
| A102 | Fixed — baseline warm-up explicit, never GREEN (8697734); see Audit_Response_HCK_CORE.md |
| A103 | Fixed — expected group set ZCD_HCK_AGGGRP, silent group measures 0 (9358d1e); see Audit_Response_HCK_CORE.md |
| A104 | Fixed (documentation) — QA case EBS-13 on the FEB source, EBS-13a file source; see Audit_Response_EBS.md |
| A105 | Fixed (documentation) — 195 parity corrected (run-level vs payment-level), legacy references pinned, PAR-195; see Audit_Response_EBS.md |

**Verification (offline):** abaplint 2.120.92 (`v758` = S/4HANA 2023) 0 issues; ATC-equivalent rule set: 3 documented exemptions (`ATC_Validation.md` §4); portable checks 15/15; generator fixture tests OK; 648 ABAP Unit test methods declared (not executed); CI green on every push.

# Legacy Parity Comparison — BAI validators → EBS rule engine

> **First principle:** business rules are copied from legacy, not reasoned out. Every difference is deliberate, listed here and covered by a test.
> **Analogy:** moving house with an inventory list — every box that left the old house is ticked off in the new one, and anything thrown away is written down with the reason.

**Baseline compared:** `BAI_Validators_ABAP75_Refactor_Pack_v4_FIX195_DOC1R` (29 Dec 2025, latest validator logic) and `bai-validation-framework-COMPLETE (4)` (latest mass-validator framework). Earlier packs (COMPLETE 1–3, refactor v1–v3, `ZFIR_BANK_POST_VALIDATION_V2`) were read for intent only. Conflicts with the first framework `jaideep247/src` are in §3a.

**Pinned legacy references (A105).** Every legacy statement below refers to the sources archived in this repository at commit `0a4a6b0ea1b2469cd8714fc5579bf98303d6442c` (unchanged since):
- v4 validators: `legacy/bai_validators_v4/` — e.g. `legacy/bai_validators_v4/zcl_bai_195_disb.clas.abap`
- COMPLETE 4 framework: `legacy/bai_validation_framework_complete4/src/` — e.g. `legacy/bai_validation_framework_complete4/src/validators/zcl_bai_195_disb.clas.abap`
- Line numbers quoted are those of the files at that commit.

**Status:** Draft — parity is proven by the unit tests named below (not yet executed in SAP) and must be confirmed by a shadow run in QA1 (§4).

## 1. Validator-by-validator parity

| Legacy validator (v4) | Legacy checks | New: BTC map row → rule group | New rules (ZCD_BTC_RULE) | Unit test proving it | Parity |
|---|---|---|---|---|---|
| ZCL_BAI_166_DISB | CHECT format alnum; DFKKRP exists for OPBEL = CHECT; DFKKRK-STARS = 5 | BAI2 166 / flow D → `BAI166D` | R04 (PARAM2 ALNUM), R07L (PARAM1 AF, PARAM2 AP, PARAM3 LOT), R07 (PARAM1 RETURNED) — retrieval-log chain, business decision (audit A11, C1 closed) | `r04_alnum_format_enforced`, `r07l_ap_passes_without_lot`, `r07l_af_with_lot_passes`, `r07l_af_without_lot_fails`, `r07l_chain_no_retrieval`, `r07l_chain_other_status` | **Different (D1, D3, D16)** |
| ZCL_BAI_166_COLL_CLEAR | BSEG(BUKRS '1000', FEBEP-BELNR) exists and AUGBL filled | BAI2 166 / flow C → `BAI166C` | R19 (PARAM1 CLEARED) | `r19_uncleared_doc_fails` | **Different (D1, D2)** |
| ZCL_BAI_168_DISB | DFKKRP+DFKKRK STARS = 5; DPAYH by DOC1R status RETURNED; ZCD_ACH_RTRV_LOG status AF | BAI2 168 / D → `BAI168D` | R04, R07R (5), R07 (RETURNED), R07L (AF) | `r07r_…`, `r07_not_returned_fails`, `r07l_retrieval_not_af_fails` | **Different (D1, D3, D4, D5)** |
| ZCL_BAI_195_DISB | DPAYH exists by DOC1R | BAI2 195 / D → `BAI195D` | R04, R07 | `r07_missing_payment_fails` | Same (key length D6) |
| ZCL_BAI_255_DISB | DFKKCR exists by ZTNUM; CRSTATUS ≠ 99 | BAI2 255 / D → `BAI255D` | R04, R07C (PARAM1 99) | `r07c_cancelled_check_fails` | **Different (D1, D6)** |
| ZCL_BAI_275_DISB | BELNR must be empty | **Removed by business decision 2026-11-06**: 275 is mapped as a ZBA sweep (flow `*`, category T02) without code-specific validation; disposition NOT_POSTED (never posted, S10 accepts it unposted — audit A26) | — | `sweep_275_575_not_validated`, `s10_unposted_sweep_ok`, `disposition_not_posted` | **Removed (D14)** |
| ZCL_BAI_466_DISB | BSEG exists for BELNR/GJAHR (no BUKRS) | BAI2 466 / D → `BAI466D` | R19 | `r19_missing_doc_fails` | **Different (D1, D2)** |
| ZCL_BAI_468_DISB | ZCD_ACH_RTRV_LOG by AUGBL status AF | BAI2 468 / D → `BAI468D` | R04, R07L (AF) | `r07l_retrieval_not_af_fails` | **Different (D1, D5)** |
| ZCL_BAI_575_DISB | BELNR must be empty | **Removed by business decision 2026-11-06**: 575 is mapped as a ZBA sweep (flow `*`, category T02) without code-specific validation; disposition NOT_POSTED (never posted, S10 accepts it unposted — audit A26) | — | `sweep_275_575_not_validated`, `s10_unposted_sweep_ok`, `disposition_not_posted` | **Removed (D14)** |
| ZCL_BAI_581_DISB | Per check: DFKKCR exists, RWBTR = KWBTR; whole input: sum and count equal; extra DFKKCR | BAI2 581 / D → `BAI581D` | R04, R08 (tol 0.00), R12 (tol 0.00) | `r08_check_amount_mismatch`, `r08_within_tolerance_passes`, `r12_code_total_mismatch` | **Different (D7)** |
| *(any code without a validator)* | silently not validated | X01 — no map row | R14 (built in, BLOCK) + S09 | `unmapped_btc_always_blocks`, `unmapped_code_always_blocked` | **Different (D8)** |

## 2. Deliberate differences

| # | Legacy behaviour | New behaviour | Why | Test that fails on the legacy behaviour |
|---|---|---|---|---|
| D1 | **v4 filters `FOR ls IN lt_f` on the table being built** in 8 of 10 validators — 166C, 166D, 168D, 255D, 275D, 466D, 468D, 575D (only 195 and 581 read `it_febep`) → the filtered table is always empty → **every line passes unchecked** | Engine routes each line by its BTC map row; rules receive the lines of their group | Silent pass of every 166/168/255/466 line is a defect, not behaviour to keep | `new_code_needs_config_only`, `group_rule_skips_other_codes` |
| D2 | Company code hard-coded `'1000'` (166C) or missing (466D, BSEG read without BUKRS) | Company code of the statement (FEBKO-BUKRS / ZCD_EBS_ACCT) | Hard-coded org unit; key access without BUKRS is a full scan on BSEG | `r19_uncleared_doc_fails` (BUKRS from statement) |
| D3 | DFKKRP matched on **OPBEL = CHECT** | DFKKRP matched on **SELW1 = payment document** (confirmed path *Return → payment: DFKKRP-SELW1 = DFKKOP-AUGBL*); lot status still read through DFKKRP-OPBEL → DFKKRK as in v4 | v4 compared the bank reference with the returns document number. **VERIFY in QA1 with a real returned payment.** | `return_item_found_by_selw1` (OSQL) |
| D4 | DPAYH status field `ZZPAYMENT_STATUS` | `ZZ_PAYMENT_STATUS` (landscape reference: "live status in DPAYH-ZZ_PAYMENT_STATUS") | Field name taken from the confirmed landscape facts. **VERIFY-DDIC.** | — (DAO field list) |
| D5 | Retrieval status field `ZZ_RTRV_STATUS` (168) vs `ZZRETRIEVAL_STATUS` (468) — the two v4 validators disagree | One field, configurable: ZCA_PARAM `EBS_RTRV_STATUS_FIELD` (default `ZZ_RTRV_STATUS`), validated against the DDIC before use | One of the v4 classes cannot have activated. **VERIFY-DDIC and maintain the parameter.** | — (DAO) |
| D6 | Keys padded inconsistently: AUGBL to 10, DOC1R to 16, ZTNUM to 20 characters | Document numbers (OPBEL/AUGBL/DOC1R) normalised to 12 digits (`EBS_KEYLEN_DOCNO`); ZTNUM used **as delivered** (`EBS_KEYLEN_ZTNUM` = 0) because DFKKCR-ZTNUM = FEBEP-CHECT | Confirmed join paths; lengths are parameters | `keys_padded_to_doc_length` |
| D7 | 581 totals over the **whole run input**; DFKKCR read into a table unique by ZTNUM (second register row per check lost); "extra DFKKCR" branch unreachable | R08 per check sums **all** register rows per ZTNUM; R12 totals per **statement** and rule group | Totals across statements hide offsetting errors; dropping register rows hides reissues | `r08_check_amount_mismatch`, `r12_code_total_mismatch` |
| D8 | A code without validator class is never checked | Unmapped/deactivated code → R14 BLOCK finding, line blocked, S09 coverage per statement | Requirements baseline principle 5: no silent suspense | `unmapped_btc_always_blocks` |
| D9 | Flow type (D/C) configured but **not applied** — both 166 D and 166 C validators received every 166 line | Flow from XBLNR pattern (ported `ZB_BAI_GL_CONFIG`) else account default (ZCD_EBS_ACCT); map rows per flow | Collections and disbursements share codes with different meaning | `xblnr_pattern_beats_account`, `flow_row_beats_any_flow_row` |
| D10 | Results only for failed records; unmapped/unchecked lines invisible | Run header counts every line (passed/failed/blocked/warning); findings are owned exceptions with SLA | Auditability (SOX) | `unmapped_code_always_blocked` |
| D11 | Failure-rate stop after 3 chunks > 50 % (hard-coded), alert to a hard-coded fallback address | Same circuit breaker, thresholds in ZCA_PARAM (`EBS_CB_*`); alerts through ZCD_OPS_ALRULE only, no hard-coded address | Same business rule, now configuration | `circuit_breaker_aborts_run` |
| D12 | Lookups took the **first** matching row (DPAYH, retrieval log, returns lot, register); legacy read one row too | R07 / R07L / R07R pass when **any** matching record has an allowed status (several runs, retry attempts, several lots — same principle as `ZCD_PAYM_REQ_LOG` SUCCESS); R07C fails when **any** register row is cancelled (fail closed). R12 compares two populations: bank entries (count, total) against the **distinct** register rows they match — a register row counts once even when several entries carry its number (audit A08) | The first row returned by the database is not the business-authoritative record (audit 2026-11-06) | `r07_any_run_with_status_ok`, `r07l_any_af_attempt_passes`, `r07r_any_done_lot_passes`, `r07c_any_cancelled_row_fails`, `r12_equal_total_other_count`, `r12_register_row_not_reused` |
| D13 | Check register matched across house banks when the statement had no house bank | Matched only when every candidate row is in one house bank account; otherwise HOUSE_BANK_AMBIGUOUS (R07C, R08, R12). The account is company code / house bank / account ID everywhere (A25); a register row of another company code never matches (A07, `EBS_DFKKCR_BUKRS_FIELD`); check numbers compare without leading zeros. R18 reports GL_ACCOUNT_NOT_MAPPED instead of skipping | No silent pass; account isolation (audit 2026-11-06) | `r08_unknown_bank_ambiguous`, `r08_unknown_bank_single_ok`, `r18_unmapped_gl_reported`, `r08_other_company_ignored`, `r08_leading_zeros_match`, `s07_two_accounts_same_number` |
| D14 | 275 / 575 (ZBA sweeps): BELNR must be empty (rule R20 in groups BAI275D / BAI575D) | **No validation** — both codes stay mapped through the sweep rows (category T02, flow `*`), so they are never blocked by R14; groups BAI275D / BAI575D and rule R20 are removed | Business decision 2026-11-06: no need for 275 / 575 validation | `sweep_275_575_not_validated` |
| D15 | BAI 143 and 452 had no validator (blocked / unprocessed in production) | **143 → BAI166C on collection accounts only** (disbursement: R14 blocks); **452 → BAI468D** | Business decision 2026-11-06; configuration only (ZCD_BTC_MAP) | `bai143_collections_only`, `bai452_validated_as_468` |
| D16 | 166 disbursement: returns lot status 5 only (v4) vs retrieval chain (`src`) | Retrieval log AP passes alone; AF needs the DFKKRP item by SELW1; then DPAYH RETURNED (R07L PARAM2 / PARAM3, R07) | Business decision (audit A11) closes conflict C1 | `r07l_chain_no_retrieval`, `r07l_chain_other_status` |
| D17 | References cut to the key length (substring / CONV); two references sharing their first characters matched the same document | Width checked before conversion: REF_TOO_LONG / REF_FORMAT / KEY_LENGTH_CONFIG, never truncated | No false match (audit A65) | `r07_refs_share_12_chars`, `r07_key_length_over_width` |
| D18 | Duplicates only within one run | R09 within the statement **plus** R22 against earlier imported statements of the account (look-back N days) | Business decision (audit A14) | `r22_entry_in_earlier_stmt`, `r22_own_statement_ignored` |
| D19 | Control totals: an empty trailer field counted as matching | TRAILER_FIELD_MISSING; a declared zero is still compared; S12 count discrepancies are findings | Omission is not zero (audit A86) | `trailer_49_total_missing`, `trailer_99_fields_missing`, `trailer_zero_is_declared` |
| D21 | Return / NOC reason of an imported entry: v4 did not check it; `src` (A28) read a configured FEBEP field — but FEBEP carries no reason (user correction 2026-11-06) | Bank file: the file's NACHA code, mapped (unchanged). FEB source: returns lot DFKKRP-RLGRD (SELW1 = payment document) and NOC lot DFKKNRP-FLGRD (INFOF = payment document or reference) — filled, one per payment, a configured payment engine reason; no lot item = not evaluated; R05 NEEDS_POSTING | User correction 2026-11-06 | `ltc_r05_lot_reason` (11 tests), `r05_skips_unposted_entry`, `noc_item_found_by_infof` |
| D22 | Every FEBEP line of the selected statements was validated, whatever account it belonged to | Only statements whose every line carries an active payment engine account in FEBEP-XBLNR (bank text + 10-character account + counter; `ZCD_EBS_ACCT-ACCOUNT_NO`) are validated and shown; a mixed statement, a blank XBLNR or a statement without lines is out of scope — no finding, counted in the run message, earlier exceptions not resolved | User decision 2026-11-06: validations and dashboards for payment engine accounts only | `mixed_statement_skipped`, `mixed_statement_no_findings`, `mixed_statement_not_reconcil`, `ltc_pe_account` (derivation), CDS `mixed_statement_hidden` |
| D20 | Validators read FEBEP whatever its posting state: a line not posted yet (FEBP or the clearing job still running) failed the FI-document / clearing / returns-lot checks (166C, 466D, 168D, 468D) | Batch run after import, FEBP and clearing (operating model 2026-11-06); a line expected to post but not posted (FEBEP posting-area flags, VERIFY-SE11 VB1OK / VB2OK) is not evaluated by the NEEDS_POSTING rules (R07, R07L, R07R, R18, R19, R21, S10): counted unevaluated, one POSTING_INCOMPLETE (S13) per statement, run never green; NOT_POSTED lines (275 / 575) excluded | A timing gap is not a payment break — neither a false failure nor a false pass | `open_entry_skips_dep_rules`, `open_entry_is_unevaluated`, `open_entries_one_finding`, `open_entry_run_never_green`, `not_posted_map_no_finding` |

## 3. Legacy framework defects not carried over (COMPLETE 4 / earlier packs)

| Defect | Where | Effect | New design |
|---|---|---|---|
| `COMMIT WORK` inside `SELECT … PACKAGE SIZE … ENDSELECT` | ZCL_BAI_MASS_VALIDATOR | Cursor closed → runtime error on the 2nd package | Statement-keyed packages, commit between packages (`ZCL_CD_EBS_SRC_FEB`) |
| Validator instances cached across chunks, statistics accumulate (`ADD 1`) but `total_count` overwritten | Factory + validators | Wrong pass/fail counts | Counts derived from findings per package (`count_lines`) |
| 195: **run-level** match instead of a payment-level match (corrected 2026-11-06, A105 — an earlier version of this row said the counter was never incremented; it is: `ADD 1 TO lv_count` for every DPAYH row whose LAUFD / LAUFI equal `CHECT+0(8)` / `CHECT+8(5)`, `zcl_bai_195_disb.clas.abap` lines 37–39 and 56–60) | COMPLETE 4 | A line passes when **any** payment of the payment run (LAUFD + LAUFI) exists, so a wire whose own payment is missing passes as long as another payment of the same run exists; `COUNT_ZERO` only when the whole run is unknown | v4 payment-level lookup: DPAYH by DOC1R derived from CHECT (`legacy/bai_validators_v4/zcl_bai_195_disb.clas.abap` lines 41–65, 91–92) → R07; QA case PAR-195 (§4) |
| `DATA(lv_checks) = ''` (type C length 1) | COMPLETE 4 | Failure codes truncated to one letter | Typed finding structure |
| `READ TABLE … WHERE`, `DATA(x) TYPE … VALUE` | 275, 468, 581 (COMPLETE 4) | Do not compile | — |
| `RETURNING … TYPE TABLE OF`, undeclared exception raised | Factory, query service | Do not compile | — |
| `get_failed_records` returns every record of the batch | DB layer | Misleading output | Findings store holds only findings |
| Duration by subtracting `timestampl` values | Several | Wrong across minute boundaries | `cl_abap_tstmp=>subtract` (`zcl_cd_ops_util=>elapsed_ms`) |
| Message 010 defined twice (I and E) | ZBAI message class | Wrong text at runtime | Single class ZCD_OPS with ranges |
| Flow derivation by amount sign / DFKKOP `AUGBL = … OR …` full scan | ZFIR_BANK_POST_VALIDATION_V2 | Wrong flow; database load | Configured patterns and account default |
| NOC app reads DFKKRNP/DFKKRNIT | NOC_Fiori_App | Tables do not exist in this landscape | FMON lot reader configured for DFKKNRK/DFKKNRP |
| Free-text dynamic SQL from customizing; `WRITE` lists; `GUID_CREATE` | Morning report (Z_HEALTH_CHECK_REPORT_FINAL) | SQL injection surface; no ALV/background output | Whitelisted, DDIC-validated aggregate checks; ALV + HTML e-mail (HCK payment engine area) |

## 3a. Third reference: first framework `jaideep247/src` (`ZCL_CD_BANK_VAL_*`)

Repository `jaideep247/src`, commit `b17df42` (uploaded 18–19 Jan 2026; git history does not show when the logic was written, so it cannot be ranked against v4 by date). It was **never activated as it stands**: `ZCL_CD_BANK_VAL_VORGC_581` line 119 declares `DATA(…) TYPE HASHED TABLE`, which does not compile. It is a reference for intent, not proof of DDIC names.

### Conflicts between the three references — business decision needed

| # | Topic | v4 validators | `src` | ops-suite today | Decision needed / how to close |
|---|---|---|---|---|---|
| C1 | **166 disbursement** | DFKKRP exists, lot status 5 | Retrieval log: status AP → pass; otherwise DFKKRP by SELW1 must exist **and** retrieval status AF; then DPAYH status RETURNED | **Closed (audit A11):** R04 + R07L (AF; AP alone; LOT) + R07 (RETURNED) — the `src` chain | None — D16 |
| C2 | 168 disbursement | DFKKRP lot status 5, DPAYH RETURNED, retrieval AF | DFKKRP by SELW1, DPAYH RETURNED (no lot status, no retrieval check) | v4 set (stricter) | Confirm the lot-status and retrieval checks are wanted for 168 |
| C3 | 195 | DPAYH exists by DOC1R | Placeholder: wire check not implemented, every line valid | v4 (R07) | None — `src` has no rule here |
| C4 | Retrieval status field in ZCD_ACH_RTRV_LOG | ZZ_RTRV_STATUS (168) / ZZRETRIEVAL_STATUS (468) | ZZ_RTRVL_STATUS | Parameter `EBS_RTRV_STATUS_FIELD`, default ZZ_RTRV_STATUS, validated against the DDIC | **SE11**: three candidate names; set the parameter to the real one |
| C5 | Amounts for 581 | DFKKCR-RWBTR vs FEBEP-KWBTR | DFKKCR-WRBTR vs FEBEP-WRBTR | DFKKCR-RWBTR vs FEBEP-KWBTR (VERIFY-DDIC) | **SE11**: which DFKKCR amount field exists |
| C6 | DOC1R key length (DPAYH) | 16 | 24 | 12 (`EBS_KEYLEN_DOCNO`) | **SE11** DPAYH-DOC1R length and one real DPAYH row in QA1 |
| C7 | 581 register rows | Unique by ZTNUM | Unique hashed by ZTNUM; single read `UP TO 1 ROWS` without ORDER BY; 300-second cache | All rows per ZTNUM summed, scoped to the house bank account; no cache | None — D7 |

### What `src` confirms and what is not taken

- **Confirms** D3: `src` also joins DFKKRP by **SELW1** (not OPBEL), and uses parameterised status values — both already in ops-suite.
- **Not taken:** the TTL cache (stale data inside a financial validation; ops-suite reads per package), global `*_TD` test-double classes (ops-suite uses local `LTD_*`), exceptions for business outcomes (`ZCX_BANK_VAL_*_ERROR` per failed line — ops-suite writes findings), the 195 placeholder.

### Capability comparison by folder (`src` vs ops-suite)

| `src` folder | What it holds | ops-suite | Verdict |
|---|---|---|---|
| validator, dao, helper, cfg, config, types | Code-specific validators, DAOs, key normalisation, constants | Rule engine, BTC map, `ZCL_CD_EBS_SAP_DAO`, parameters | Covered — conflicts C1–C7 above |
| cache | TTL cache (300 s) | Kernel table buffering of customizing; no ABAP cache | Not taken (stale data in a financial check) |
| exc | One exception class per failed check | Findings; `ZCX_CD_OPS_ERROR` for technical failure only | Not taken (review 3.7) |
| factory (12), injector | A factory per concern | One factory + injector per payment engine area | Covered |
| log, msg, util (BAL wrapper, message wrapper) | Application log, messages | APPLOG channel, message class ZCD_OPS | Covered |
| util — notification service | E-mail, Teams, Slack, critical / health / performance alerts | Alert router: rules, throttle, quiet hours, escalation; channels EMAIL and APPLOG | **Different** — e-mail and SLG1 covered, more configurable; no outbound Teams / Slack call (read-only scope, 2026-11-07) |
| util — parameter loader, SQL utilities, query builder | ZZCD_PARAMS by area; dynamic query builder | Global framework ZCA_PARAM (areas CD_*; typed, validated on every read, errors logged and reported as PARAM_INVALID); DDIC-validated, whitelisted dynamic SQL with injection tests | Covered |
| monitor — health check | Tables exist (DD02L), parameters present, authorisation, performance | HCK payment engine area, health of the health check | Covered for runtime health. Configuration completeness is covered by R14 (unmapped codes) and DDIC validation at run time, not by a separate check |
| monitor — metrics, performance profiler | Timers per step, statistics | Run runtime, HCK runtime per check with timeout guard | Covered at run / check level; no per-rule timing (add only if QA1 performance needs it) |
| report — job / dump monitor | TBTCO, dumps, mail | HCK job cycle, SNAP, TBTCO checks, morning report | Covered |
| report — business report | Result list | ALV in the three reports, CDS analytics | Covered |
| job — daily job, scheduler | `JOB_OPEN` / `JOB_CLOSE` from ABAP | Control-M schedules the reports | Not taken (landscape standard is Control-M) |
| **job — archive job, processor `archive_old_results`** | **Deletes results older than N days (dry run, retention parameter)** | **No retention for any ops-suite table** | **Gap G1** |
| audit | Audit entries kept in an internal table, never saved | Run and findings in ZCD_OPS_RUN / ZCD_OPS_FINDING; alert log | Not taken (not persisted). Related gap closed: customizing tables now carry the change-log flag (SCU3) |
| **rap** | Behaviour pool with action `validateBankStatements` and 2 CDS views; no service definition or binding, so not usable | **Read-only CDS analytics; no way to assign, resolve or waive an exception** | **Gap G2** (the runbook asks operations to do it) |
| **security** | Custom authorisation object with activity and company code | `S_PROGRAM` in `ZCD_EBS_VALIDATE`, `S_TABU_NAM` for baselines; nothing in FMON / HCK reports; no company-code restriction | **Gap G3** |
| test — integration (CRITICAL), performance (DANGEROUS) | End-to-end, archive, notification; batch sizes, concurrency | QA1 functional, parity and performance cases (Test and Validation §11) | Covered as QA1 cases, not as unit tests |
| test — security | Assertions are `assert_true( abap_true )` — they always pass | Real tests: injected names rejected, quotes escaped, whitelist | Not taken |
| database, ddic | Result, summary, audit, parameter tables; CDS on FEBEP | 30 tables, 11 CDS | Covered |
| docs, improvements, operations (79 md) | Design notes | Archived in `legacy/framework_v1_docs` | — |

**Gaps to close (proposed):** G1 retention — a purge report for runs, findings, alert log, FMON events and HCK metrics, with retention days per table in ZCA_PARAM and a test mode. G2 exception maintenance — assign, resolve and waive with reason, history and authorisation (ALV report, or a RAP business object with a Fiori elements app). G3 authorisation — object `ZCD_OPS` (activity, payment engine area, company code) used by the three reports and by G2.

## 4. How parity is confirmed before go-live (QA1)

1. Run legacy `Z_BAI_MASS_VALIDATION` (v4 validators, with defect D1 corrected locally so they actually check) and `ZCD_EBS_VALIDATE` in **test mode** on the same FEBKO/FEBEP date range.
2. Compare per BAI code and line: legacy failed checks vs new findings. Every difference must map to a row D1–D11; anything else is a defect.
3. Record results in the Test and Validation document §7 and attach the comparison extract (no production data in chat or e-mail).

**PAR-195 — 195 run-level vs payment-level (A105).** In QA1 pick one payment run (LAUFD + LAUFI) with at least two wire payments and build three BAI 195 lines: (a) CHECT of an existing payment of the run; (b) CHECT carrying the same LAUFD / LAUFI but a payment key (DOC1R) that does not exist in DPAYH; (c) LAUFD / LAUFI of no run. Expected: COMPLETE 4 passes (a) and (b), fails (c) with `COUNT_ZERO`; v4 and `ZCD_EBS_VALIDATE` pass (a) and report (b) and (c) (R07 `PAYMENT_NOT_FOUND`). Line (b) is the deliberate difference; record it as such. `VERIFY-SE11`: CHECT layout (LAUFD 8 + LAUFI 5) and DPAYH-DOC1R length (C6).

The shadow run is the only proof of parity; unit tests prove the code does what was decided, not that it was decided the same way as before.

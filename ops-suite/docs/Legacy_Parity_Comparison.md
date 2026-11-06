# Legacy Parity Comparison — BAI validators → EBS rule engine

> **First principle:** business rules are copied from legacy, not reasoned out. Every difference is deliberate, listed here and covered by a test.
> **Analogy:** moving house with an inventory list — every box that left the old house is ticked off in the new one, and anything thrown away is written down with the reason.

**Baseline compared:** `BAI_Validators_ABAP75_Refactor_Pack_v4_FIX195_DOC1R` (29 Dec 2025, latest validator logic) and `bai-validation-framework-COMPLETE (4)` (latest mass-validator framework). Earlier packs (COMPLETE 1–3, refactor v1–v3, `ZFIR_BANK_POST_VALIDATION_V2`) were read for intent only.

**Status:** Draft — parity is proven by the unit tests named below (not yet executed in SAP) and must be confirmed by a shadow run in QA1 (§4).

## 1. Validator-by-validator parity

| Legacy validator (v4) | Legacy checks | New: BTC map row → rule group | New rules (ZCD_BTC_RULE) | Unit test proving it | Parity |
|---|---|---|---|---|---|
| ZCL_BAI_166_DISB | CHECT format alnum; DFKKRP exists for OPBEL = CHECT; DFKKRK-STARS = 5 | BAI2 166 / flow D → `BAI166D` | R04 (PARAM2 ALNUM), R07R (PARAM1 5) | `r04_alnum_format_enforced`, `r07r_lot_status_not_5_fails` | **Different (D1, D3)** |
| ZCL_BAI_166_COLL_CLEAR | BSEG(BUKRS '1000', FEBEP-BELNR) exists and AUGBL filled | BAI2 166 / flow C → `BAI166C` | R19 (PARAM1 CLEARED) | `r19_uncleared_doc_fails` | **Different (D1, D2)** |
| ZCL_BAI_168_DISB | DFKKRP+DFKKRK STARS = 5; DPAYH by DOC1R status RETURNED; ZCD_ACH_RTRV_LOG status AF | BAI2 168 / D → `BAI168D` | R04, R07R (5), R07 (RETURNED), R07L (AF) | `r07r_…`, `r07_not_returned_fails`, `r07l_retrieval_not_af_fails` | **Different (D1, D3, D4, D5)** |
| ZCL_BAI_195_DISB | DPAYH exists by DOC1R | BAI2 195 / D → `BAI195D` | R04, R07 | `r07_missing_payment_fails` | Same (key length D6) |
| ZCL_BAI_255_DISB | DFKKCR exists by ZTNUM; CRSTATUS ≠ 99 | BAI2 255 / D → `BAI255D` | R04, R07C (PARAM1 99) | `r07c_cancelled_check_fails` | **Different (D1, D6)** |
| ZCL_BAI_275_DISB | BELNR must be empty | BAI2 275 / D → `BAI275D` | R20 | `r20_posted_line_fails` | **Different (D1)** |
| ZCL_BAI_466_DISB | BSEG exists for BELNR/GJAHR (no BUKRS) | BAI2 466 / D → `BAI466D` | R19 | `r19_missing_doc_fails` | **Different (D1, D2)** |
| ZCL_BAI_468_DISB | ZCD_ACH_RTRV_LOG by AUGBL status AF | BAI2 468 / D → `BAI468D` | R04, R07L (AF) | `r07l_retrieval_not_af_fails` | **Different (D1, D5)** |
| ZCL_BAI_575_DISB | BELNR must be empty | BAI2 575 / D → `BAI575D` | R20 | `r20_posted_line_fails` | **Different (D1)** |
| ZCL_BAI_581_DISB | Per check: DFKKCR exists, RWBTR = KWBTR; whole input: sum and count equal; extra DFKKCR | BAI2 581 / D → `BAI581D` | R04, R08 (tol 0.00), R12 (tol 0.00) | `r08_check_amount_mismatch`, `r08_within_tolerance_passes`, `r12_code_total_mismatch` | **Different (D7)** |
| *(any code without a validator)* | silently not validated | X01 — no map row | R14 (built in, BLOCK) + S09 | `unmapped_btc_always_blocks`, `unmapped_code_always_blocked` | **Different (D8)** |

## 2. Deliberate differences

| # | Legacy behaviour | New behaviour | Why | Test that fails on the legacy behaviour |
|---|---|---|---|---|
| D1 | **v4 filters `FOR ls IN lt_f` on the table being built** in 8 of 10 validators — 166C, 166D, 168D, 255D, 275D, 466D, 468D, 575D (only 195 and 581 read `it_febep`) → the filtered table is always empty → **every line passes unchecked** | Engine routes each line by its BTC map row; rules receive the lines of their group | Silent pass of every 166/168/255/466 line is a defect, not behaviour to keep | `new_code_needs_config_only`, `group_rule_skips_other_codes` |
| D2 | Company code hard-coded `'1000'` (166C) or missing (466D, BSEG read without BUKRS) | Company code of the statement (FEBKO-BUKRS / ZCD_EBS_ACCT) | Hard-coded org unit; key access without BUKRS is a full scan on BSEG | `r19_uncleared_doc_fails` (BUKRS from statement) |
| D3 | DFKKRP matched on **OPBEL = CHECT** | DFKKRP matched on **SELW1 = payment document** (confirmed path *Return → payment: DFKKRP-SELW1 = DFKKOP-AUGBL*); lot status still read through DFKKRP-OPBEL → DFKKRK as in v4 | v4 compared the bank reference with the returns document number. **VERIFY in QA1 with a real returned payment.** | `return_item_found_by_selw1` (OSQL) |
| D4 | DPAYH status field `ZZPAYMENT_STATUS` | `ZZ_PAYMENT_STATUS` (landscape reference: "live status in DPAYH-ZZ_PAYMENT_STATUS") | Field name taken from the confirmed landscape facts. **VERIFY-DDIC.** | — (DAO field list) |
| D5 | Retrieval status field `ZZ_RTRV_STATUS` (168) vs `ZZRETRIEVAL_STATUS` (468) — the two v4 validators disagree | One field, configurable: ZCD_OPS_PARAM `EBS_RTRV_STATUS_FIELD` (default `ZZ_RTRV_STATUS`), validated against the DDIC before use | One of the v4 classes cannot have activated. **VERIFY-DDIC and maintain the parameter.** | — (DAO) |
| D6 | Keys padded inconsistently: AUGBL to 10, DOC1R to 16, ZTNUM to 20 characters | Document numbers (OPBEL/AUGBL/DOC1R) normalised to 12 digits (`EBS_KEYLEN_DOCNO`); ZTNUM used **as delivered** (`EBS_KEYLEN_ZTNUM` = 0) because DFKKCR-ZTNUM = FEBEP-CHECT | Confirmed join paths; lengths are parameters | `keys_padded_to_doc_length` |
| D7 | 581 totals over the **whole run input**; DFKKCR read into a table unique by ZTNUM (second register row per check lost); "extra DFKKCR" branch unreachable | R08 per check sums **all** register rows per ZTNUM; R12 totals per **statement** and rule group | Totals across statements hide offsetting errors; dropping register rows hides reissues | `r08_check_amount_mismatch`, `r12_code_total_mismatch` |
| D8 | A code without validator class is never checked | Unmapped/deactivated code → R14 BLOCK finding, line blocked, S09 coverage per statement | Master prompt principle 5: no silent suspense | `unmapped_btc_always_blocks` |
| D9 | Flow type (D/C) configured but **not applied** — both 166 D and 166 C validators received every 166 line | Flow from XBLNR pattern (ported `ZB_BAI_GL_CONFIG`) else account default (ZCD_EBS_ACCT); map rows per flow | Collections and disbursements share codes with different meaning | `xblnr_pattern_beats_account`, `flow_row_beats_any_flow_row` |
| D10 | Results only for failed records; unmapped/unchecked lines invisible | Run header counts every line (passed/failed/blocked/warning); findings are owned exceptions with SLA | Auditability (SOX) | `unmapped_code_always_blocked` |
| D11 | Failure-rate stop after 3 chunks > 50 % (hard-coded), alert to a hard-coded fallback address | Same circuit breaker, thresholds in ZCD_OPS_PARAM (`EBS_CB_*`); alerts through ZCD_OPS_ALERT_RULE only, no hard-coded address | Same business rule, now configuration | `circuit_breaker_aborts_run` |

## 3. Legacy framework defects not carried over (COMPLETE 4 / earlier packs)

| Defect | Where | Effect | New design |
|---|---|---|---|
| `COMMIT WORK` inside `SELECT … PACKAGE SIZE … ENDSELECT` | ZCL_BAI_MASS_VALIDATOR | Cursor closed → runtime error on the 2nd package | Statement-keyed packages, commit between packages (`ZCL_CD_EBS_SRC_FEB`) |
| Validator instances cached across chunks, statistics accumulate (`ADD 1`) but `total_count` overwritten | Factory + validators | Wrong pass/fail counts | Counts derived from findings per package (`count_lines`) |
| 195: counter never incremented → every line `COUNT_ZERO` | COMPLETE 4 | All 195 lines fail | v4 DOC1R logic (R07) |
| `DATA(lv_checks) = ''` (type C length 1) | COMPLETE 4 | Failure codes truncated to one letter | Typed finding structure |
| `READ TABLE … WHERE`, `DATA(x) TYPE … VALUE` | 275, 468, 581 (COMPLETE 4) | Do not compile | — |
| `RETURNING … TYPE TABLE OF`, undeclared exception raised | Factory, query service | Do not compile | — |
| `get_failed_records` returns every record of the batch | DB layer | Misleading output | Findings store holds only findings |
| Duration by subtracting `timestampl` values | Several | Wrong across minute boundaries | `cl_abap_tstmp=>subtract` (`zcl_cd_ops_util=>elapsed_ms`) |
| Message 010 defined twice (I and E) | ZBAI message class | Wrong text at runtime | Single class ZCD_OPS with ranges |
| Flow derivation by amount sign / DFKKOP `AUGBL = … OR …` full scan | ZFIR_BANK_POST_VALIDATION_V2 | Wrong flow; database load | Configured patterns and account default |
| NOC app reads DFKKRNP/DFKKRNIT | NOC_Fiori_App | Tables do not exist in this landscape | FMON lot reader configured for DFKKNRK/DFKKNRP |
| Free-text dynamic SQL from customizing; `WRITE` lists; `GUID_CREATE` | Morning report (Z_HEALTH_CHECK_REPORT_FINAL) | SQL injection surface; no ALV/background output | Whitelisted, DDIC-validated aggregate checks; ALV + HTML e-mail (HCK module) |

## 4. How parity is confirmed before go-live (QA1)

1. Run legacy `Z_BAI_MASS_VALIDATION` (v4 validators, with defect D1 corrected locally so they actually check) and `ZCD_EBS_VALIDATE` in **test mode** on the same FEBKO/FEBEP date range.
2. Compare per BAI code and line: legacy failed checks vs new findings. Every difference must map to a row D1–D11; anything else is a defect.
3. Record results in the Test and Validation document §7 and attach the comparison extract (no production data in chat or e-mail).

The shadow run is the only proof of parity; unit tests prove the code does what was decided, not that it was decided the same way as before.

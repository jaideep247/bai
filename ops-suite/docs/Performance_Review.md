# Performance review — eight fixes, sorted / hashed tables, field symbols (2026-11-06)

> **First principle:** the fastest read is the one that is not repeated — ask the database once for exactly the rows (or the totals) the decision needs, then look them up by key, never by scanning.
> **Analogy:** a librarian who fetches every book a class needs in one trip and shelves them by call number — instead of walking to the stacks once per pupil and then reading every spine to find the right one.

Pure performance work: **behaviour unchanged**, every existing ABAP Unit test still holds (the FMON lot-reader truncation test and two FEB source tests were re-shaped where the access path itself changed — §2 fix 3 and fix 8). Where a change carries a parity risk (keys, counts, SQL aggregation) a test was added: 20 new test methods, 2 moved from the SAP DAO to the FEB DAO (754 declared methods including the merged posting-state and dashboard work).

Verified offline only: abaplint (v758) 0 issues, ATC-equivalent rule set 3 documented exemptions, `tools/portable_checks.py` 15/15. **Not verified:** activation, ABAP Unit execution, HANA plans and run times — measure in DV1/QA1 (§7, §8).

## 1. Where the time went

| # | Hot spot (before) | Multiplier |
|---|---|---|
| 1 | Cheque rules R07C / R08 / R12: every bank line looped over every DFKKCR row, canonicalising both sides (and reading a parameter) per row; R12 did it twice per line; K01 runs R07C + R08 and BAI 581D runs R08 + R12 on the same keys | lines × register rows × rules |
| 2 | R22 (line rule, group `*`) read the 5-day FEBKO/FEBEP history per statement, once per rule group | statements × rule groups |
| 3 | FEB source read FEBEP three times per package (items, reason field, posting flags) and searched the header and reason tables linearly per item | 3 reads, items × headers |
| 4 | R07 / R07L / R07R / R19: `LOOP … WHERE` on STANDARD result tables per bank line | lines × result rows |
| 5 | Carry-forward / reconcile: WHERE PE_AREA + OBJECT_KEY could use only PE_AREA of index OBJ (PE_AREA, OBJECT_TYPE, OBJECT_KEY); nested `LOOP lt_prev WHERE` | open exceptions of the area × new findings |
| 6 | R18: one ACDOCA `SUM` per closing statement | statements |
| 7 | HCK metric history: up to 5 000 points per series read, latest point per run kept in ABAP | metrics × 5 000 |
| 8 | FMON lot reader: up to `FMON_MAX_ROWS` (50 000) item rows read to count total / done / open | lots × items |

## 2. The eight fixes

| # | Before (access pattern) | After (access pattern) | Objects | Tests added |
|---|---|---|---|---|
| 1 | Per line: `LOOP AT lt_checks` + `ztnum_canonical( )` (with `param( )`) per row; `house_bank_ambiguous( )` and `checks_for_line( )` each scanned again; each rule read DFKKCR itself | `check_register( )`: DFKKCR through a **package memo shared by R07C/R08/R12** (`CLASS-DATA`; a key is read once per package; a new statement-key set clears it; `ZCL_CD_EBS_INJECTOR` clears it in tests), each row canonicalised once into a **SORTED** index (non-unique key `canonical`, read order kept); `register_match( )` = one keyed `LOOP … WHERE canonical =` per line for ambiguity and house-bank scoping; parameters read once per call | `ZCL_CD_EBS_RULE_BASE`, R07C, R08, R12, `ZCL_CD_EBS_INJECTOR` | `r08_zero_flag_off_rows_apart`, `r08_zero_flag_on_rows_merged` (EBS_ZTNUM_IGNORE_ZEROS parity), `register_read_once_package`, `register_new_package_rereads`, `register_memo_keys_not_leak` |
| 2 | `get_recent_items( )` per statement and rule group | **Instance memo** in R22 (package statement keys + look-back days): one read per house bank account over the union of its statements' windows; each statement's own window applied in ABAP on the new `TY_ITEM-AZDAT` (FEBKO-AZDAT), repository order (KUKEY, ESNUM) kept so the lowest KUKEY still wins; lines by secondary key `STMT`. SQL push-down not done (deferred) | R22, `ZIF/ZCL_CD_EBS_FEB_DAO` | `r22_history_once_per_package`, `r22_windows_per_statement`; OSQL assert on AZDAT |
| 3 | FEBEP read for items (FEB DAO), again for the reason field (removed 2026-11-06: FEBEP carries no reason — R05 reads DFKKRP-RLGRD with the R07R statement and DFKKNRP-FLGRD) and again for the posting flags (SAP DAO); `mt_headers[ kukey ]` and `lt_reasons[ kukey esnum ]` on STANDARD tables | **One FEBEP read**: `get_items( is_extras )` appends the configured reason field (`… AS reason`, only when it is a FEBEP field — DDIC check unchanged) and the posting-area flags (`… AS flag1..4`, at most four, unknown name raises 051 — unchanged) to the item field list; header currency by **HASHED** key KUKEY; `get_febep_reasons` / `get_febep_posting` removed from the SAP DAO (FEB source was their only caller), their OSQL tests moved | `ZCL_CD_EBS_SRC_FEB`, `ZIF/ZCL_CD_EBS_FEB_DAO`, `ZIF/ZCL_CD_EBS_SAP_DAO` | `items_with_posting_flags` (was `items_with_reason_and_flags`; `unknown_reason_field_ignored` removed with the reason field 2026-11-06); posting-flag tests moved to the FEB DAO; FEB source tests count the reads |
| 4 | `LOOP AT lt_payments / lt_retrievals / lt_items / lt_fi_lines WHERE …` on STANDARD EMPTY KEY tables | STANDARD primary key kept (read order — DPAYH newest run first), **non-unique sorted secondary keys** `BY_DOC1R`, `BY_AUGBL`, `BY_SELW1`, `BY_DOCUMENT`; loops `USING KEY`, `line_exists( …[ KEY by_selw1 … ] )` | R07, R07L, R07R, R19, `ZIF_CD_EBS_SAP_DAO` | `r07_rows_by_doc_key_parity` |
| 5 | WHERE PE_AREA + OBJECT_KEY on index OBJ (PE_AREA, OBJECT_TYPE, OBJECT_KEY); nested `LOOP lt_prev WHERE type/key/check` per new finding | Index **OBJ = (MANDT, PE_AREA, OBJECT_KEY)** (reconcile and the exception repository cannot know the type — the EBS engine passes keys only); carry-forward reads **(OBJECT_TYPE, OBJECT_KEY) pairs**; earlier rows found by `READ … BINARY SEARCH` on the newest-first sort and a bounded `LOOP … FROM` (a sorted key cannot keep CREATED_AT descending inside the block) | `ZCL_CD_OPS_STORE`, `ZCL_CD_OPS_EXC_DAO`, `ddic/core/zcd_ops_finding.tabl.ddl` (+ regenerated XML) | `carry_other_type_untouched`, `carry_newest_prior_inherited` |
| 6 | `SELECT SUM( tsl ) … INTO @rv_balance` per statement | **One statement**: `ACDOCA JOIN @it_requests` (company code, G/L account, currency, statement date, request no) `GROUP BY request_no` — same filters and SUM; a request without postings has no row = 0 as before; `get_gl_balance` replaced by `get_gl_balances` | R18, `ZIF/ZCL_CD_EBS_SAP_DAO` | `r18_one_read_per_package`; OSQL `gl_balances_per_request`, `gl_balances_empty_requests` |
| 7 | Up to 5 000 points per series, de-duplicated per run in ABAP | `WITH +points AS ( … ROW_NUMBER( ) OVER( PARTITION BY run_id ORDER BY measured_at DESCENDING ) AS rn ) SELECT … WHERE rn = 1 ORDER BY measured_at DESCENDING, run_id DESCENDING INTO TABLE … UP TO iv_max_rows ROWS` — series grain incl. DIM2 (A101), as-of bound, completed-run filter and the warm-up count (A102) unchanged | `ZCL_CD_HCK_DAO` | `history_runs_by_latest_point` |
| 8 | `read_legacy` of up to 50 000 item rows, counted in ABAP | **`count_legacy`**: the same validated path (name re-check, ZCD_OPS_TABWL approval (FMON / SOURCE), S_TABU_NAM, bound IN list) with `GROUP BY (fields)` and `COUNT(*) AS ROW_COUNT` into an RTTI table typed from the DDIC — one row per link / lot and status, **no row cap**; `is_done( )` stays in ABAP (UPPER, condense, blank token — SQL cannot match `condense` exactly) and is applied once per distinct status; open keys (≤ 5 per file) read only for links / lots that have open items | `ZCL_CD_FMON_LOT_READER`, `ZIF/ZCL_CD_FMON_DAO`, `ZIF_CD_FMON_TYPES` | `item_counts_exact_beyond_cap`, `no_open_items_no_key_read`; OSQL `grouped_count_per_status`, `grouped_count_needs_approval` |

### Behaviour notes (parity)

- **Fix 1 memo lifetime.** The memo is shared by the rule classes (they are separate plug-in instances) and bound to the package by its statement keys. Within one package R07C, R08 and R12 now see one DFKKCR snapshot (before: three reads milliseconds apart). A second validation of the *identical* statement set in the same internal session would reuse the rows; the engine therefore calls `ZCL_CD_EBS_RULE_BASE=>CLEAR_MEMO( )` at the start of `validate_package` (done in the EBS engine sweep, test `same_statements_reread`); the batch report validates each statement once per run.
- **Fix 1 key parity.** Rows from the memo are filtered to the call's own query keys, so a line never sees a row that its group's read would not have returned (test `register_memo_keys_not_leak`).
- **Fix 3.** With one read an item can no longer be missing from a second (posting) read, so "posting state unknown for an item that was read" no longer arises; every item read gets P or O when posting fields are configured, as a consistent database would have given before.
- **Fix 7.** The old 5 000-point cap could cut off runs when a series had many points per run; the database now ranks every run — the result is the same whenever the old read was not truncated.
- **Fix 8.** `LOT_SCAN_TRUNCATED` (A38) now comes only from a capped **lot (header) read**; item counts are exact. A capped open-key sample never marks the batch truncated (its counts are exact) but may show fewer keys.

## 3. Why no AMDP

Every hot spot is a set operation ABAP SQL on HANA expresses directly: keyed reads (FOR ALL ENTRIES / IN lists on indexed keys), `JOIN @itab … GROUP BY` (fix 6), window functions in a CTE (fix 7) and dynamic `GROUP BY` with `COUNT(*)` (fix 8). All of it is pushed to HANA by the ABAP SQL interface already. An AMDP would add a second language and transport object, a `USING` list of SAP tables (FEBEP, DFKKCR, ACDOCA) to maintain, client handling, and — for fix 8 — dynamic table names that SQLScript cannot take without dynamic SQL inside the procedure (worse for the security review than the DDIC-validated ABAP path). The remaining cost was repetition and linear search in ABAP, which an AMDP does not remove. Conclusion: no AMDP; revisit only if a DV1/QA1 measurement shows a single statement (not its repetition) dominating.

## 4. Sorted / hashed tables

| Area | Object | Change |
|---|---|---|
| EBS | rule base | register index SORTED by canonical number; statements HASHED by key; memo keys HASHED |
| EBS | FEB source | header currency HASHED by KUKEY |
| EBS | `ZIF_CD_EBS_SAP_DAO` | secondary keys BY_DOC1R, BY_AUGBL, BY_SELW1, BY_DOCUMENT, BY_KEY (R21 lookup rows); G/L requests SORTED, balances HASHED |
| EBS | R22 | history HASHED by account |
| FMON | `ZIF_CD_FMON_TYPES` | files: secondary keys BY_ID (lot / NOC checks), BY_IFACE (late check); events: BY_FILE (SLA verdict, engine de-duplication) |
| FMON | engine | findings summarised per file reference in one HASHED pass (board and run totals no longer scan all findings per file) |
| FMON | lot reader | links de-duplicated by hash; done / open statuses HASHED |
| HCK | DAO | TBTCP first steps in a SORTED table (no SORT + BINARY SEARCH) |
| HCK | `ZIF_CD_HCK_TYPES` | baselines: secondary key BY_TABLE (config drift) |
| HCK | tech jobs, aggregate query | job identities / measured groups de-duplicated by hash |
| Core | store | carry-forward keys SORTED unique (type, key); binary search on the newest-first sort (§2 fix 5) |
| Core | trace | document headers: secondary key BY_OPBEL |
| EBS | engine | rules: sorted secondary keys BY_RULE (blocking flag per finding), BY_GROUP (configuration gaps per line), BY_POSTING (posting-dependent rule per line); execution order stays the primary order; alert classes of the kept findings hashed (was a scan of up to `EBS_RESULT_MAX` findings per class); read-only loops as field symbols; `clear_memo( )` at the start of `validate_package` |

Kept STANDARD on purpose: result tables whose **order** is part of the behaviour (DPAYH newest run first, FEBEP KUKEY/ESNUM, findings in raise order) — secondary keys added instead; types of the **public interfaces** used by RAP / generated code (`TT_FINDING`, `TT_STATEMENT`, `TT_LINE` already has key STMT); **tiny configuration tables** read once per statement (house bank accounts, SLA rows, check definitions, thresholds); tables where uniqueness is not guaranteed (no unique keys there — no ITAB_DUPLICATE_KEY risk; `INSERT` not `INSERT LINES OF` into unique tables, e.g. R12's distinct-row set).

## 5. Field symbols

177 `LOOP AT … INTO DATA(wa)` became `ASSIGNING FIELD-SYMBOL(<wa>)`: EBS 41, FMON 36, HCK 51, Core 49 (plus the loops rewritten by the fixes themselves). A loop was converted only when the work area is provably read-only (scripted scan of every loop, then abaplint): not assigned, cleared or passed for change (CHANGING / `c*_` parameters / RECEIVING / `INTO` / `OF STRUCTURE` / `REF #`), not used after the loop, the looped table not changed in the loop (nor its rows through another field symbol), not a `GROUP BY` loop, field-symbol name free, and — for attribute tables changed elsewhere in the class — no own method call in the loop body.

Kept as `INTO` (71 evaluated loops): the work area is changed as a local copy or passed for change (50 — e.g. RAP message rows, R05 / BTC map rows, FMON group records, CSV / HTML builders), attribute table changed elsewhere while the loop calls methods (9 — FMON engine `mt_files` / `mt_lotcfgs`, trace engine attempts), work area used after the loop (5), loop changes the looped table (3), name taken (2), `GROUP BY` loops (2). `MODIFY TABLE mt_files FROM ls_file` in the FMON engine stays: the row comes from a hashed table and is changed through a CHANGING method (no write through a field symbol into a key table). `READ TABLE … INTO` (21) and `DATA(wa) = itab[ … ]` (20) were not converted: their not-found handling (initial values, `CX_SY_ITAB_LINE_NOT_FOUND`) would change. Generated RAP behaviour pools (`tools/rap_generate.py`) and test includes were not touched; the EBS engine followed in the modern-syntax sweep with the same rules (21 loops / reads as field symbols, three secondary keys, see §4).

## 6. Deferred

| Item | Why deferred |
|---|---|
| R22 SQL push-down (duplicate match in SQL) | Fix 2 removes the repetition; push-down changes the evidence path (KUKEY of the first duplicate) and needs a FEBEP index check |
| HCK G/L-gap count merge (A43 list + total in one statement) | Two light reads; merge with window COUNT when measured |
| Trace batched reads (`get_items_by_clearing` per document, per-FIN request reads) | Interactive, one payment per call; batch when support reports latency |
| S01 / S03 prior-header memo (`get_prior_header` per statement) | One keyed read per statement; memo per account and package like fix 2 |
| FMON event writes (`insert_event` per event, bounded retry) | Documented ATC exemption; array insert needs a new collision strategy |
| FMON open-key sample: status filter on the sample read | Needs a second IN condition in the validated query type |

## 6a. Scaling and data volume (decisions)

1. **Scaling route: parallel job variants, no mass-activity framework.** More throughput comes from several SM36 / Control-M jobs of the same report with **non-overlapping selections** (company code / house bank / statement-key ranges for EBS, interface or source ranges for FMON, check categories for HCK). The run lock key includes the **variant** (`ZIF_CD_OPS_LOCK` acquire per payment engine area and variant; a held lock is refused by `ZCL_CD_OPS_RUN_GUARD`), so parallel variants never block each other while the same variant cannot run twice. A mass-activity (FKKMA) integration would add a second scheduling model, its own parallelisation objects and restart logic for a workload that packages already bound — not justified by the volumes known today.
2. **HANA table partitioning only as a Basis decision after gate 3 volumes.** Partitioning `ZCD_OPS_FINDING`, `ZCD_OPS_RUN`, `ZCD_FMON_EVENT` or `ZCD_HCK_METRIC` is considered only when the gate 3 (QA1 / production-like) volumes show row counts in the **hundreds of millions** for a table; the purge (`ZCD_OPS_PURGE`, retention days per table in ZCA_PARAM) is already packaged and keeps the tables at their retention size. Partitioning is a Basis / DBA decision (range on the date / run ID, re-partitioning effort), not an application change.
3. **HCK date literals as host variables (low value).** A few HCK aggregate reads compare a date column with a literal computed in ABAP and embedded into the dynamic WHERE (escaped via `cl_abap_dyn_prg`). Binding them as host variables would let HANA reuse one statement plan per check instead of one per day — low value (one execution per check and day, statement cache absorbs it); noted, not built.

## 6b. Patterns are matched in ABAP, not in SQL (PCRE, 2026-11-06)

Configured patterns are PCRE matched to the complete value, case ignored. ABAP SQL `LIKE_REGEXPR( PCRE = …, VALUE = … )` was probed and **not used**: abaplint 2.120.92 does not parse it (the offline lint gate), and a regular expression on HANA cannot use an index either (the former `CP` range became `LIKE 'ZCD_%'`, which could). The reads stay bounded by their non-pattern conditions:

| Read | Before (CP range in SQL) | After |
|---|---|---|
| TBTCO job runs (job cycle, technical jobs, job runtime) | `jobname IN @range` + date window, UP TO 5 000 | `SELECT DISTINCT jobname` of the date window (UP TO `HCK_MAX_JOB_NAMES` names, default 20 000, ceiling 200 000; at the cap message 747, the check fails loudly), PCRE in ABAP, runs of the matched names by FOR ALL ENTRIES + date window, sorted and capped at `HCK_MAX_JOB_ROWS` (default 5 000, ceiling 50 000) |
| TBTCO unresolved jobs | `jobname IN @range` + open statuses | distinct names of the open statuses, then as above (oldest first) |
| BALHDR counters | `object IN @range` + day | grouped per object / subobject for the day (one row per pair), PCRE in ABAP |
| Job cycles | `cycle_id IN @range` | active cycles (customizing rows), PCRE in ABAP |
| Pattern check values | — | `SELECT DISTINCT` of the source column in the window, ORDER BY, UP TO P_MAX |

Cost: the distinct-name read scans the date window of TBTCO instead of a name prefix — a few thousand names per day; measure at gate 3 together with the morning report runtime. `matches( )` caches compiled expressions per pattern.

## 7. VERIFY-ADT (first activation / ABAP Unit in DV1)

- Fix 6: internal table as JOIN source (`INNER JOIN @it_requests`) — on HANA since 7.52; also inside `cl_osql_test_environment` with the ACDOCA double.
- Fix 7: window function in a CTE (`ROW_NUMBER( ) OVER( PARTITION BY … )`) inside `cl_osql_test_environment`.
- Fix 8: dynamic `GROUP BY (fields)` / `ORDER BY (fields)` with `COUNT(*) AS ROW_COUNT` into an RTTI-created table, on the doubles of the configured tables.
- Fix 3: dynamic FEBEP field list with `AS reason` / `AS flag<n>` into `INTO CORRESPONDING FIELDS` (FEBEP double); VB1OK / VB2OK confirmed 2026-11-07.

## 8. VERIFY-SE11 — indexes the access paths rely on

| Table | Fields | Used by |
|---|---|---|
| FEBEP | CHECT | EBS references (R22 history, trace) |
| DPAYH | DOC1R | R07 |
| DFKKRP | SELW1 | R07R, R07L |
| DFKKCR | ZTNUM; DOC1R | R07C / R08 / R12; trace |
| DFKKOP | AUGBL; ZZ_FIN_TRANS_NUM | trace, HCK payment request rules |
| BKPF | AWTYP + AWKEY | HCK G/L transfer gaps |
| DFKKKO | BUDAT | HCK G/L transfer gaps |
| DFKKSUMC | FIKEY | HCK G/L transfer gaps |
| BUT000 | BPEXT | payment request → partner |
| FEBKO | (BUKRS, HBKID, HKTID, AZDAT) | R22 history (fix 2), S01 / S03 prior header |
| ZCD_ACH_RTRV_LOG | AUGBL | R07L |
| DFKKNRP | INFOF — **not a key field**; the read is an IN list of the exact forms of the payment document / reference (bounded by the lines of a package) | R05 NOC reason (FLGRD), payment trace NOC evidence |
| ZCD_OPS_FINDING | OBJ = (MANDT, PE_AREA, OBJECT_KEY) — **changed by fix 5** | carry-forward, reconcile, exception repository |
| DFKKOP | BUDAT (with ZZ_FIN_TRANS_NUM) | transactions dashboard (`ZI_CD_TrxItem`: FIN items of the 400-day retention, the chosen day(s) by date kind) — on HANA the date predicate may be a column scan; record ST05 / PlanViz at peak (TXD-12) |
| DPAYH | DOC1R (and XVORL) | transactions dashboard payment-run evidence |
| DFKKCR | DOC1R | transactions dashboard cheque evidence |
| FEBEP | CHECT | transactions dashboard bank settlement / encashment |
| DFKKRP | SELW1 | transactions dashboard returns |
| DFKKNRP | INFOF (not a key) | transactions dashboard NOCs — driven by the bounded item set |

**FEBEP-XBLNR has no index (and needs none).** The payment engine account scope (user decision 2026-11-06) is derived from XBLNR, but never searched by it: the engine applies it in ABAP to the lines of a package already read by KUKEY (one hashed lookup per line in the set of active accounts); the dashboard (`ZI_CD_EbsLineAcct` → `ZI_CD_EbsStmtScope`) computes the account per line of the bounded FEBKO / FEBEP set (statement date in the last 31 days, FEBEP by KUKEY) and joins it to the few active `ZCD_EBS_ACCT` rows — the join is driven by that bounded set, not by an XBLNR access path. The scope view aggregates every line of the window once per request (record the runtime in EBD-12; a materialised scope is the fallback if it is slow).

BSEG is a physical table on S/4HANA (read by key BUKRS / BELNR / GJAHR only); BSIS / BSAS are compatibility views — never read them for performance-critical paths.

## In-flight evidence reads (A_INFLIGHT, 2026-11-07)

One batch read per evidence kind and run (FOR ALL ENTRIES over the payment documents of the window, capped by `HCK_INFLIGHT_MAX_ROWS`): FEBEP by CHECT (index on CHECT expected), DPAYH by DOC1R, DFKKCR by DOC1R, DFKKRP by SELW1, DFKKOP by AUGBL (Stripe intent IDs), the Stripe payout log by the intent field, and **BSEG by BUKRS + XREF2 + GJAHR** (`ZCL_CD_HCK_RUNTIME_DAO=>GET_GL_LINES_BY_XREF2`). BSEG has no standard index on XREF2: before gate 1 take an SQL trace (ST05) in QA1 with a production-like window; if the statement scans, either create a secondary index BUKRS / XREF2 or restrict by the G/L clearing accounts (PARAM1 of the GL_XREF2 / GL_ZUONR rule rows). ACDOCA / the compatibility views do not carry XREF2 for this purpose (VERIFY in QA1). No SELECT runs per payment.


## 9. Three-way reconciliation reads (A_RECON_3WAY, 2026-11-07)

> **First principle:** a reconciliation of millions of lines is a handful of totals - let HANA add them up and bring back only the totals.

Every leg is **one set-based statement per run** (bank, G/L, subledger, payments for all THREEWAY / ACH sets together; Stripe and ACH reads per set of that kind, a few sets), aggregated on HANA with `GROUP BY` and `SUM` / `COUNT` / `MIN` / `MAX`; the result has one row per account (or key) × currency × day × code / reference procedure, i.e. tens to hundreds of rows, never the lines. No `SELECT` per document, no `FOR ALL ENTRIES`, no line copied into the suite's tables (results only: `ZCD_HCK_METRIC` rows `RC_*` and findings). The rules (`ZCL_CD_HCK_RECON_EVAL`) work on the totals in memory.

| # | Read (`ZCL_CD_HCK_RECON_DAO`) | Statement | Bound / access path | VERIFY-SQL-trace (QA1, ST05 / PlanViz, production-like volume) |
|---|---|---|---|---|
| R1 | `GET_BANK_DAYS` | `ZI_CD_HckRcBankLine` (FEBEP ⋈ FEBKO on KUKEY, XBLNR account by `REPLACE_REGEXPR`) `WHERE PeAccount IN @accounts AND BookingDate BETWEEN` … `GROUP BY` account, currency, day, code, D/C | FEBEP-BUDAT window (look-back days, default 7) filtered first; the account expression is evaluated on the window's lines only (column store), the IN list holds the few set accounts | The plan filters BUDAT before the regex (no full FEBEP scan); runtime for 7 days of all accounts; if the regex dominates, a FEBKO filter (BUKRS / HBKID / HKTID of the sets, index noted in §8) is the fallback - the scope must stay the XBLNR account (EBS) |
| R2 | `GET_BANK_LAST_DAYS` | same view, `MAX( BookingDate )` per account | Window from the first day to the report date | As R1 |
| R3 | `GET_BANK_DAYS_NO_LOT` | same view, `NOT EXISTS ( SELECT … FROM dfkkrp WHERE selw1 = BankReference )`, REDEPOSIT codes only | Window + code IN list; anti-join on DFKKRP by SELW1 (index of §8) | Semi-join uses the SELW1 index, not a DFKKRP scan; CHECT / SELW1 in the same form |
| R4 | `GET_GL_DAYS` | ACDOCA `INNER JOIN @keys` (company code, account, transaction currency) `WHERE rldnr = AND budat BETWEEN` `GROUP BY` …, day, AWTYP | Ledger + company code + account + posting date (ACDOCA column store; no secondary index needed on HANA) | Statement runtime for the clearing accounts of all sets over the window; JOIN @itab pushed to HANA (as EBS R18, fix 6) |
| R5 | `GET_FICA_DAYS` | DFKKSUMC `INNER JOIN @keys` `WHERE budat BETWEEN` `GROUP BY` …, day | Posting date of the summary records (VERIFY-SE11 DFKKSUMC-BUDAT; index FIKEY of §8 does not help a date read) | Date predicate is a column scan of DFKKSUMC - record runtime; if slow, drive by the window's reconciliation keys (DFKKSUM / DFKKKO-BUDAT, index of §8) |
| R6 | `GET_PAYMENT_DAYS` | DPAYH `INNER JOIN @banks` `WHERE laufd BETWEEN AND xvorl = space AND doc1r <> space` `GROUP BY` …, run date | Run date window (as `A_INFLIGHT`) | Same access as the in-flight payment read |
| R7 | `GET_DEPOSITS` | `ZI_CD_HckRcBankLine` DEPOSIT codes `GROUP BY` posting document | As R1, code IN list | As R1 |
| R8 | `GET_DOC_ASSIGNMENTS` | ACDOCA `INNER JOIN @docs` (BUKRS, BELNR, GJAHR) on the Stripe clearing account `GROUP BY` …, ZUONR, DRCRK | Primary key of ACDOCA (document) - a few deposit documents | Key access |
| R9 | `GET_ASSIGNMENT_SUMS` | ACDOCA company code + account + currency + posting window (look-back × 2) + `zuonr IN @descriptors` `GROUP BY` ZUONR, DRCRK | Few descriptors per window; ZUONR has no ACDOCA index - the account and date bound the scan | Runtime of the descriptor read on the Stripe clearing account; if needed a secondary index RACCT / ZUONR (Basis decision) |
| R10 | `GET_OPEN_ASSIGNMENTS` | ACDOCA company code + account + currency + window (look-back + timing + redeposit days) `GROUP BY zuonr HAVING SUM( wsl ) <> 0`, `UP TO HCK_RECON_MAX_ROWS` | Only open groups come back (netting pairs are dropped on HANA) | Grouping of the ACH collection clearing account over ~20 days: rows scanned vs returned; the cap (default 5 000, ceiling 50 000) bounds memory |

**Why ACDOCA and not BSEG / BSIS / BSAS.** BSEG has no index by account (read by document key only, §8); BSIS / BSAS are compatibility views. The account-and-date reads go to ACDOCA (column store) - the "within BSEG" one-to-one of ACH collections is the assignment field ZUONR, read on ACDOCA (VERIFY-SE11 that ACDOCA-ZUONR equals BSEG-ZUONR after the payout processing changes it).

**CDS for the bank leg.** The XBLNR account cannot be computed in ABAP SQL without a regular expression in the WHERE clause (not parsed by the offline lint, §6b); the view entity `ZI_CD_HckRcBankLine` holds the same derivation as `ZI_CD_EbsLineAcct` (one ABAP source, `cds_abap_parity`), so the bank lines are scoped exactly as EBS scopes them and aggregated where they are. It has no own date window: the DAO always passes one.
## 10. Canonical payment outcome — 5-minute snapshot and history (2026-11-07)

> **First principle:** the cost of a snapshot must follow the evidence that arrived, not the number of payments that exist.
> **Analogy:** a post office sorts today's letters - it does not re-read every letter ever delivered to see whether something changed.

**Work per run = new evidence, never the payment population.** Each evidence source keeps its own watermark (`ZCD_PAY_OUTWM`) and is read after it in key order, one package at a time (`PAYOUT_PACKAGE_SIZE`, default 5 000 payment documents, ceiling 50 000; at most `PAYOUT_MAX_PACKAGES` = 20 packages per source and run, the rest waits for the next 5-minute run):

| Source | Read after the watermark (tuple order, package) | Index / access path (VERIFY-SE11) |
|---|---|---|
| DOCUMENTS - new payment runs and new / changed DFKKOP clearing | DFKKKO (CPUDT, CPUTM, OPBEL) > watermark, EXISTS DFKKOP AUGBL = OPBEL with FIN | DFKKKO by CPUDT (secondary index or HANA column scan); DFKKOP by AUGBL (standard) |
| REVERSALS - a payment already judged reversed | DFKKKO of the reversal document (CPUDT, CPUTM, OPBEL) > watermark, joined to the original by STBEL | DFKKKO by CPUDT; DFKKKO by STBEL (VERIFY) |
| STATEMENT - FEBEP lines | (KUKEY, ESNUM) > watermark, CHECT not blank - primary key range; references = payment documents (E G H I J K L) or cheque numbers (DFKKCR-ZTNUM = CHECT → DOC1R) | FEBEP primary key; first run: MIN( KUKEY ) of BUDAT ≥ start date |
| RETURNS - DFKKRP lots | return document DFKKKO (CPUDT, CPUTM, OPBEL) > watermark, EXISTS DFKKRP; then DFKKRP-SELW1 by OPBEL (FOR ALL ENTRIES) | DFKKKO by CPUDT; DFKKRP by OPBEL (key) |
| GL - BSEG clearing of XREF2 | BKPF (CPUDT, CPUTM, BUKRS, BELNR, GJAHR) > watermark; BSEG by BUKRS + AUGBL + AUGGJ with XREF2 (FOR ALL ENTRIES) | BKPF by CPUDT (VERIFY); BSEG by AUGBL (VERIFY - secondary index, else restrict to the clearing accounts) |
| RECHECK - DPAYH-ZZ_PAYMENT_STATUS, DFKKCR-STATE (no change stamp) | current versions whose outcome is not final (IN_FLIGHT, PENDING, UNDETERMINED, INCONSISTENT, AMBIGUOUS), AUGBL > cursor, one package per run, cursor wraps | `ZCD_PAY_OUTCOME` index **OUT** (OUTCOME, VALID_TO) |

The payment documents of a package are judged together by the shared evaluator: DPAYH by DOC1R (latest run per document), then one batch read per evidence kind (as A_INFLIGHT, capped by `HCK_INFLIGHT_MAX_ROWS`); FIN items by AUGBL (FOR ALL ENTRIES), request sources by FIN (one IN-list read of the configured request log), current versions by FIN (index **FIN**). **No SELECT runs per payment.** A capped evidence read fails the package closed: nothing is written, the watermark stays, `PAY_OUTCOME_FAILED` (E) - lower `PAYOUT_PACKAGE_SIZE`.

**Volume reasoning.** Millions of payments exist, but per 5 minutes only the payments with new evidence are touched: at, say, 200 000 payments a day and about four evidence events per payment (payment run, statement line, status, clearing), a run sees about 2 800 documents (one package). The recheck adds at most one package of the payments still in flight (the population in flight is days of payments, not years). Writes: a version only when the outcome changes - about two to four versions per payment over its life (IN_FLIGHT → CLEARED, sometimes INCONSISTENT on the way); an unchanged evaluation writes nothing (not even an evaluation time), so the table grows with outcome changes, not with runs. 400 days at 200 000 payments a day ≈ 80 million payments → about 200-300 million narrow rows (keys + 20-character outcome + short reference); the purge target `PAY_OUTCOME` keeps it at that size; HANA partitioning by LAUFD only if gate 3 volumes require it (§6a). No amount, date, partner or method is copied: the dashboard joins DPAYH / DFKKOP / FEBEP / ZCD_PAYM_REQ_LOG by key.

**Indexes of `ZCD_PAY_OUTCOME`** (key FIN_ID, SOURCE, BUKRS, AUGBL, LAUFD, LAUFI, VALID_FROM):

| Index | Fields | Serves |
|---|---|---|
| DAT | MANDT, BUKRS, LAUFD | dashboard run-date filter per company code; purge of payment runs before the cutoff |
| OUT | MANDT, OUTCOME, VALID_TO | current outcome cards (VALID_TO = 99991231235959), recheck of outcomes not final, purge of closed versions |
| FIN | MANDT, FIN_ID, SOURCE | request side (FIN + source), snapshot read of the current versions of a package's FIN numbers (primary key prefix as well) |

**Dashboard reads.** The "as of" version is a range predicate on VALID_FROM / VALID_TO joined by FIN + company code + payment document from the bounded item set (DFKKOP with FIN, BUDAT ≥ today − 400; the date kind narrows it to the chosen day(s)); KPI and problem cards read the current version (as of today 23:59:59) for 31 days. Aggregation is HANA's (CDS GROUP BY, OData `$apply`); the authorisation key (company code) is a pass-through GROUP BY key, so the DCL condition equals the condition on the base rows (`Dashboard_Transactions.md` §8). Record PlanViz for each date kind at peak (TXD-12).

**VERIFY-SE11 (indexes):** DFKKKO-CPUDT / CPUTM / STBEL; BKPF-CPUDT / CPUTM; BSEG-AUGBL / AUGGJ; DPAYH-DOC1R (and the DPAYH key: LAUFD + LAUFI + DOC1R unique?); DPAYH-VALUT (value-date filter: column scan on HANA, acceptable for a day range); FEBKO-KUKEY assigned ascending (number range) so that (KUKEY, ESNUM) is an arrival order.

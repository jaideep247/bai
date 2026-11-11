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
| 5 | WHERE PE_AREA + OBJECT_KEY on index OBJ (PE_AREA, OBJECT_TYPE, OBJECT_KEY); nested `LOOP lt_prev WHERE type/key/check` per new finding | Index **OBJ = (MANDT, PE_AREA, OBJECT_KEY)** (reconcile and the exception repository cannot know the type — the EBS engine passes keys only); carry-forward reads **(OBJECT_TYPE, OBJECT_KEY) pairs**; earlier rows found by `READ … BINARY SEARCH` on the newest-first sort and a bounded `LOOP … FROM` (a sorted key cannot keep CREATED_AT descending inside the block) | `ZCL_CA_OPS_STORE`, `ZCL_CA_OPS_EXC_DAO`, `ddic/core/zca_ops_finding.tabl.ddl` (+ regenerated XML) | `carry_other_type_untouched`, `carry_newest_prior_inherited` |
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

1. **Scaling route: parallel job variants, no mass-activity framework.** More throughput comes from several SM36 / Control-M jobs of the same report with **non-overlapping selections** (company code / house bank / statement-key ranges for EBS, interface or source ranges for FMON, check categories for HCK). The run lock key includes the **variant** (`ZIF_CA_OPS_LOCK` acquire per payment engine area and variant; a held lock is refused by `ZCL_CA_OPS_RUN_GUARD`), so parallel variants never block each other while the same variant cannot run twice. A mass-activity (FKKMA) integration would add a second scheduling model, its own parallelisation objects and restart logic for a workload that packages already bound — not justified by the volumes known today.
2. **HANA table partitioning only as a Basis decision after gate 3 volumes.** Partitioning `ZCA_OPS_FINDING`, `ZCA_OPS_RUN`, `ZCD_FMON_EVENT` or `ZCD_HCK_METRIC` is considered only when the gate 3 (QA1 / production-like) volumes show row counts in the **hundreds of millions** for a table; the purge (`ZCA_OPS_RETENTION`, retention days per table in ZCA_PARAM) is already packaged and keeps the tables at their retention size. Partitioning is a Basis / DBA decision (range on the date / run ID, re-partitioning effort), not an application change.
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
| DFKKOP | AUGBL; ZZ_FIN_TRANS_NUM (**blocking pre-check 0.8 of `Implementation_Order.md`**, 2026-11-10: read by every snapshot package at 200 000-400 000 payments a day) | trace, HCK payment request rules, payment worklist snapshot (FIN items) |
| BKPF | AWTYP + AWKEY | HCK G/L transfer gaps |
| DFKKKO | BUDAT | HCK G/L transfer gaps |
| DFKKSUMC | FIKEY | HCK G/L transfer gaps |
| BUT000 | BPEXT | payment request → partner |
| FEBKO | (BUKRS, HBKID, HKTID, AZDAT) | R22 history (fix 2), S01 / S03 prior header |
| ZCD_ACH_RTRV_LOG | AUGBL | R07L |
| DFKKNRP | INFOF — **not a key field**; the read is an IN list of the exact forms of the payment document / reference (bounded by the lines of a package) | R05 NOC reason (FLGRD), payment trace NOC evidence |
| ZCA_OPS_FINDING | OBJ = (MANDT, PE_AREA, OBJECT_KEY) — **changed by fix 5** | carry-forward, reconcile, exception repository |
| DFKKOP | BUDAT (with ZZ_FIN_TRANS_NUM) | transactions dashboard returns / NOC and request side (`ZI_CD_TrxItem`: FIN items of the 45-day evidence window; since 2026-11-08 no longer the driver of the transactions - the worklist is) — on HANA the date predicate may be a column scan; record ST05 / PlanViz at peak (TXD-12) |
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

**Work per run = new evidence, never the payment population.** Each evidence source keeps its own watermark (`ZCD_PAY_OUTWM`) and is read after it in key order, one package at a time (`PAYOUT_PACKAGE_SIZE`, default 5 000 payment documents, ceiling 50 000; at most `PAYOUT_MAX_PACKAGES` = 60 packages per source and run (20 until 2026-11-10), the rest waits for the next 5-minute run):

| Source | Read after the watermark (tuple order, package) | Index / access path (VERIFY-SE11) |
|---|---|---|
| DOCUMENTS - new payment runs and new / changed DFKKOP clearing | DFKKKO (CPUDT, CPUTM, OPBEL) > watermark, EXISTS DFKKOP AUGBL = OPBEL with FIN | DFKKKO by CPUDT (secondary index or HANA column scan); DFKKOP by AUGBL (standard) |
| REVERSALS - a payment already judged reversed | DFKKKO of the reversal document (CPUDT, CPUTM, OPBEL) > watermark, joined to the original by STBEL | DFKKKO by CPUDT; DFKKKO by STBEL (VERIFY) |
| STATEMENT - FEBEP lines | (KUKEY, ESNUM) > watermark, CHECT not blank - primary key range; references = payment documents (E G H I J K L) or cheque numbers (DFKKCR-ZTNUM = CHECT → DOC1R) | FEBEP primary key; first run: MIN( KUKEY ) of BUDAT ≥ start date |
| RETURNS - DFKKRP lots | return document DFKKKO (CPUDT, CPUTM, OPBEL) > watermark, EXISTS DFKKRP; then DFKKRP-SELW1 by OPBEL (FOR ALL ENTRIES) | DFKKKO by CPUDT; DFKKRP by OPBEL (key) |
| GL - BSEG clearing of XREF2 | BKPF (CPUDT, CPUTM, BUKRS, BELNR, GJAHR) > watermark; BSEG by BUKRS + AUGBL + AUGGJ with XREF2 (FOR ALL ENTRIES) | BKPF by CPUDT (VERIFY); BSEG by AUGBL (VERIFY - secondary index, else restrict to the clearing accounts) |
| RECHECK - DPAYH-ZZ_PAYMENT_STATUS, DFKKCR-STATE (no change stamp) | current worklist rows of payments (IN_FLIGHT, PENDING, UNDETERMINED, INCONSISTENT, AMBIGUOUS), AUGBL > cursor, one package per run, cursor wraps | `ZCD_PAY_OUTCOME` index **OUT** (OUTCOME, VALID_TO) |
| REQUESTS (2026-11-08) - payment requests with a SUCCESS attempt | request log (`TRACE_SRC_REQUEST`) after the keyset (received date, time, FIN), SUCCESS rows only, one package (FMON reader, seek condition + ORDER BY) | request log index on received date / time (VERIFY-SE11); FIN items by `ZZ_FIN_TRANS_NUM` (FOR ALL ENTRIES), DPAYH by key |
| NIGHTLY / NIGHTLYREQ (mode NIGHTLY) | every current worklist row of a payment (AUGBL > cursor) / of a request (FIN > cursor), package by package, cursor saved after each package | `ZCD_PAY_OUTCOME` index **DOC** (AUGBL) / **FIN**; bounded by `PAYOUT_BATCH_MAX_PACKAGES` |
| SWEEP (mode SWEEP) | the chosen sources between date from and date to (upper bound on CPUDT / BUDAT / received date), no watermark saved | as the source; bounded by `PAYOUT_BATCH_MAX_PACKAGES` |

The payment documents of a package are judged together by the shared evaluator: DPAYH by DOC1R (latest run per document), then one batch read per evidence kind (as A_INFLIGHT, capped by `HCK_INFLIGHT_MAX_ROWS`); FIN items by AUGBL (FOR ALL ENTRIES), request sources by FIN (one IN-list read of the configured request log), current versions by FIN (index **FIN**). **No SELECT runs per payment.** A capped evidence read fails the package closed: nothing is written, the watermark stays, `PAY_OUTCOME_FAILED` (W, an error from the `PAYOUT_FAIL_ESCALATE`-th failed run in a row, 2026-11-10) - lower `PAYOUT_PACKAGE_SIZE`.

**Volume reasoning.** Millions of payments exist, but per 5 minutes only the payments with new evidence are touched: at 400 000 payments a normal day (upper end of the 200 000-400 000 confirmed by the user 2026-11-10) and about four evidence events per payment (payment run, statement line, status, clearing), a run sees about 5 600 documents on average (two packages) and about 27 000 when an hourly payment run lands (six packages). The recheck adds at most one package of the payments still in flight (the population in flight is days of payments, not years). Writes (exceptions-only worklist, user decision 2026-11-08): an open payment has **one** current row, changed in place (UPDATE) while it stays open; when it ends clean the row is **deleted**; only an exception keeps versions (close + insert). An unchanged evaluation writes nothing (not even an evaluation time), so the table holds what needs attention, not history of every payment: ≈ **2-5 million** rows in steady state (§10a) instead of ≈ 60 million. The purge removes exception history 90 days after it closed; HANA partitioning is not needed at this size (§6a). No amount, date, partner or method is copied: the dashboard joins DPAYH / DFKKOP / FEBEP / ZCD_PAYM_REQ_LOG by key.

**Indexes of `ZCD_PAY_OUTCOME`** (key FIN_ID, SOURCE, BUKRS, AUGBL, LAUFD, LAUFI, VALID_FROM):

| Index | Fields | Serves |
|---|---|---|
| DAT | MANDT, BUKRS, LAUFD | dashboard run-date filter per company code; purge of payment runs before the cutoff |
| OUT | MANDT, OUTCOME, VALID_TO | current outcome cards (VALID_TO = 99991231235959), recheck of outcomes not final, purge of closed versions |
| FIN | MANDT, FIN_ID, SOURCE | request side (FIN + source; primary key prefix as well) |
| DOC (2026-11-08) | MANDT, AUGBL | snapshot read of the rows of a package's payment documents (every FIN / source, also FIN blank), NIGHTLY cursor, A_INFLIGHT `NOT EXISTS` of the documents not yet snapshotted and of the AMBIGUOUS-only payments |
| DUE (2026-11-08) | MANDT, DUE_DATE | A_PRQ_NOT_PAID (request rows due before today), dashboard date kind DUE |

**Dashboard reads (2026-11-08).** The rows are the current worklist rows (`ZI_CD_PayWorkItem`, VALID_TO open - index OUT), joined to DPAYH by its key; the date kind narrows them to the chosen day(s) (run date via DAT, due date via DUE, value date as a column predicate); KPI cards 30 days of worklist dates, the problem list the exceptions (FINDING filled). The former 400-day item driver and the "as of" range predicate are gone. Aggregation is HANA's (CDS GROUP BY, OData `$apply`); the authorisation key (company code) is a pass-through GROUP BY key, so the DCL condition equals the condition on the base rows (`Dashboard_Transactions.md` §8). Record PlanViz for each date kind at peak (TXD-12).

**VERIFY-SE11 (indexes):** DFKKKO-CPUDT / CPUTM / STBEL; BKPF-CPUDT / CPUTM; BSEG-AUGBL / AUGGJ; DPAYH-DOC1R (and the DPAYH key: LAUFD + LAUFI + DOC1R unique?); DPAYH-VALUT (value-date filter: column scan on HANA, acceptable for a day range); FEBKO-KUKEY assigned ascending (number range) so that (KUKEY, ESNUM) is an arrival order.

### 10a. Sizing at the confirmed volume (user 2026-11-08, re-sized 2026-11-10 for 200 000-400 000 a normal day) and the aggregate reads of A_INFLIGHT

**Volume (user 2026-11-10, was 200 000 a normal day on 2026-11-08).** **200 000 to 400 000 payments a normal day** across all sources, two peak days a month of about 2 000 000 payments each: about **8-13 million payments a month**. The figures below are sized at the upper end (400 000). **Exceptions-only worklist (user decision 2026-11-08).** `ZCD_PAY_OUTCOME` holds only what is open or wrong: payments in flight (wire 1-2, ACH / card 3-4, international ACH 7-8 business days; open cheques until cashed), requests received but not yet paid, and exceptions with their history until 90 days after they closed. At 400 000 payments a normal day that is about **2 million** open payment rows plus the open requests (about one or two days of requests); after the two peak days (2 million each) **up to about 6 million** for a few days; exceptions (inconsistent, undetermined, ambiguous, status lag, late, not paid) are a small share - tens of thousands of rows with their history. **≈ 2-6 million rows** instead of the former ≈ 60 million (90 days × about 2.5 versions of every payment). Clean payments leave the table when they finish (DELETE in the snapshot's package commit), so there is no nightly purge of clean history. The table count of the suite is 67 (the 65 of the posting-area build: 23 configuration, 27 draft, 38 non-draft, plus `ZCD_PAY_OUTPKG` and, 2026-11-10, its members `ZCD_PAY_OUTPKGM`: 40 non-draft): only `ZCD_PAY_OUTCOME` grows with the payment volume; `ZCD_PAY_OUTWM` has one row per source plus the worklist guard row, `ZCD_PAY_OUTPKG` / `ZCD_PAY_OUTPKGM` the packages of the last run of each mode.

| Object | Rows | Width (uncompressed) | Note |
|---|---|---|---|
| `ZCD_PAY_OUTCOME` | ≈ 2-6 million (worklist at 400 000 a normal day; was ≈ 60 million at 90 days of versions) | ≈ 310 bytes (keys 105, outcome / kind / finding 80, reference 100, time stamps, severity) | HANA column store: OUTCOME, FINDING, SEVERITY, EVIDENCE_KIND have a handful of distinct values (dictionary encoding), so the memory footprint is a fraction of the raw width - measure in QA1 (VOL-05); partition by LAUFD only if the measured size requires it (§6a) |
| `ZCD_PAY_OUTPKG` | ≤ 6 sources × `PAYOUT_MAX_PACKAGES` per mode | 300 bytes | deleted at the start of the next run of the same mode (2026-11-10: by mode, SWEEP shares the FAST sources) |
| `ZCD_PAY_OUTPKGM` (2026-11-10) | the documents and requests planned for the packages of the last parallel run of each mode: ≤ `PAYOUT_MAX_PACKAGES` × `PAYOUT_PACKAGE_SIZE` per source (FAST delivered: 300 000 per source since 2026-11-10, 60 × 5 000; NIGHTLY: the worklist) | 75 bytes (keys only) | written set-based with the package rows (INSERT FROM TABLE), read by the unit by package key (primary key), deleted with the packages; replaces the document list each bgPF unit carried (up to 50 000 documents per unit serialized into the bgRFC queue) |
| Purge (monthly job) | exception history closed more than 90 days ago - thousands to tens of thousands of rows | — | `PURGE_PACKAGE_SIZE` per commit; VOL-06 |
| Deletes by the snapshot | one per payment that finishes clean (≈ 200 000-400 000 a normal day, 2 million on a peak day), set-based per package (DELETE FROM TABLE) | — | part of the package commit; VOL-01 |

**Snapshot throughput.** A run reads at most `PAYOUT_MAX_PACKAGES` × `PAYOUT_PACKAGE_SIZE` documents per source (delivered since 2026-11-10: 60 × 5 000 = 300 000; was 20 × 5 000). A peak day of 2 million payments therefore needs about 7 runs (≈ 35 minutes) for the DOCUMENTS source at the delivered values, with `PAYOUT_PARALLEL` **8** (was 4) so that each run's 60 packages finish in waves of 8 bgPF units within the 5-minute cadence; at the former 20 × 5 000 it needed about 20 runs (100 minutes), outside the pass criterion "snapshot back within 60 minutes after the last payment run". **Basis:** 8 parallel units need 8 free work processes for bgRFC (inbound destination of `ZCD_PAY_SNAPSHOT_PACKAGE`) during the payment-run hours; VOL-01 measures runtime and work processes, and both values are tuned there (40-80 packages, 4-12 units); the run lock refuses an overlapping start, so a long run delays the next one but never duplicates work. Ordered watermarks keep every package that failed or was abandoned for the next run.

**A_INFLIGHT reads (one morning report).**

| Read | Access path | Rows returned |
|---|---|---|
| Watermarks | `ZCD_PAY_OUTWM` full (6 rows) | 6 |
| Groups (`GET_OUTCOME_GROUPS`) | `ZCD_PAY_OUTCOME` index **OUT** (OUTCOME, VALID_TO = 99991231235959: the current worklist rows - a few days of payments plus the stuck ones, ≈ 0.2-4 million rows after a peak; since 2026-11-08 nothing final is read - PAY_EXCLUDED retired); GROUP BY payment in a CTE, then the join to DPAYH by its key (LAUFD, LAUFI, DOC1R = AUGBL - **VERIFY-SE11** that this identifies one row without proposal runs) and T001 / TFK042Z (small) and a second GROUP BY | groups: days × methods × house banks × value dates × currencies × outcomes × findings × statuses - thousands, independent of the payment count |
| Examples (`GET_OUTCOME_EXAMPLES`) | the same CTE restricted to the run dates that have a finding (`LAUFD IN`), `ROW_NUMBER( ) OVER( PARTITION BY … ORDER BY VALUT, AUGBL )`, filter `rn <= PAYOUT_EXAMPLES` on HANA | ≤ N × partitions |
| Not yet snapshotted (`GET_UNSNAPSHOTTED`) | DPAYH by LAUFD ≥ DOCUMENTS watermark − 1 day (column scan of a day range on HANA) with `NOT EXISTS` on `ZCD_PAY_OUTCOME` index **DOC** (AUGBL, new) | ≤ `HCK_INFLIGHT_MAX_ROWS` |
| AMBIGUOUS-only | index OUT (outcome AMBIGUOUS) with `NOT EXISTS` by AUGBL / LAUFD / LAUFI (DOC index) | ≤ `HCK_INFLIGHT_MAX_ROWS` |
| ACK candidates (`GET_OUTCOME_ROWS`) | as the groups, filtered by DPAYH-ZZ_PAYMENT_STATUS IN `HCK_PAY_STATUS_ACK_OPEN`, UP TO the cap ordered by run date | ≤ `HCK_INFLIGHT_MAX_ROWS` |

No SELECT runs per payment and no internal table holds the payments in flight: memory of the check is bounded by the groups, the examples and the capped live / candidate sets. The calendars are read once per calendar and date (day table built downwards as far as the oldest group needs, at most 400 days). The snapshot's own reads by payment document now use the new index **DOC** (MANDT, AUGBL) instead of FIN (`GET_OPEN_VERSIONS`); FIN stays for the request side of the dashboard. Measure with ST05 / PlanViz in VOL-02 (A_INFLIGHT runtime and memory, SAT) and VOL-03 (dashboard).

**NIGHTLY and SWEEP (2026-11-08, re-sized 2026-11-10).** NIGHTLY re-judges every worklist row once a night: ≈ 2 million rows on a normal day at 400 000 a day (400 packages of `PAYOUT_PACKAGE_SIZE` 5 000) and up to ≈ 6 million after a peak day (1 200 packages) - delivered `PAYOUT_BATCH_MAX_PACKAGES` **1 500** (was 1 000, which a post-peak night exceeded) with `PAYOUT_PARALLEL` 8; measure the runtime in VOL-01b (pass: done before the morning report); a run stopped at the limit continues from its cursor (`PAY_BATCH_INCOMPLETE` W). Rows whose verdict is unchanged write nothing. SWEEP reads only the chosen date range and sources, at most `PAYOUT_BATCH_MAX_PACKAGES` packages, and moves no watermark. A_PRQ_NOT_PAID reads the request rows due before today (index DUE), capped by `HCK_INFLIGHT_MAX_ROWS`.

### 10b. Concurrency of the worklist and the exception store (review 2026-11-10)

**Worklist writes are optimistic, set-based.** FAST, NIGHTLY, SWEEP (own run locks) and the parallel units may judge the same payment at the same time. A package write (`SAVE_VERSIONS`) locks one guard row (`ZCD_PAY_OUTWM` / `WORKLIST`, SELECT SINGLE FOR UPDATE), re-reads the current rows of the package's payments and requests in **one keyed read per kind** (FOR ALL ENTRIES by AUGBL - index DOC - and by FIN + source - index FIN; the same reads as the judgement, current rows only) and compares them with the rows the judgement was based on (sorted tables, binary key access - no nested scan). Cost per package: one guard lock, two keyed reads of the package's rows (a few thousand), a comparison in memory. The guard serializes only the validate-and-write window of the writers (from the re-read to the package's commit: the DML of one package), never the judgement - FAST is not held up by a nightly run beyond one package write. Why a guard and not row locks: ABAP SQL takes row locks set-based only by changing the rows (SELECT ... FOR UPDATE is SELECT SINGLE) - one SELECT SINGLE FOR UPDATE per payment would be a SELECT per payment. VERIFY in QA1 (VOL-01 with `PAYOUT_PARALLEL` 8 and a NIGHTLY run at the same time): lock waits on the guard row (a database row lock, not an enqueue: DBACOCKPIT / ST04, not SM12), package write time.

**Exception store: one guarded UPDATE per state change.** The store's supersede (carry-forward) and resolve (reconcile) and the exception repository's resolve write an exception only while its disposition and `LAST_CHANGED_AT` are the ones read: `UPDATE ... SET ... WHERE run_id AND finding_no AND disposition = read AND last_changed_at = read`, sy-dbcnt compared. ABAP SQL has no set-based compare-and-set (UPDATE FROM TABLE matches by key only and would overwrite a user's waiver), so this is one primary-key UPDATE per exception whose disposition the run changes - bounded by the exceptions the run raises again (carry-forward) or evaluates without finding (reconcile), i.e. the run's own aggregated findings, not the volume of payments. The reads stay set-based (FOR ALL ENTRIES by object key, index OBJ). A row changed meanwhile is read again once (one more keyed read of those rows only). abaplint's `db_operation_in_loop` looks inside one method only; the real ATC "DB operations in loops across modularization units" may list these calls - accepted, reason above (VERIFY-ATC).

## 11. Control center reads (overview page, 2026-11-10)

Everything is counted live in the database (CDS GROUP BY / OData `$apply`); nothing is copied into a new table and no row is read in a loop. The business date of every card is a filter element, so HANA applies it to the base rows before the joins (record PlanViz in QA1, cases OVP-14 / CTL-08).

| Card | Base read and access path | Rows touched for one business date |
|---|---|---|
| **Payment lifecycle** (`ZI_CD_PayLifeRun` → `ZI_CD_PayLifeCntU` → `ZR_CD_PayLifecycle`) | **DPAYH by LAUFD** = the business date: LAUFD is the first field of the DPAYH primary key (MANDT, LAUFD, LAUFI, ... - VERIFY-SE11 the key order), so a date is a key range, not a scan; XVORL = blank and DOC1R not blank as filters. Newest run per payment document: anti-join on DPAYH by **DOC1R** (`Newer.doc1r = Pay.doc1r`, index on DOC1R VERIFY-SE11 - the same access as `ZI_CD_TrxItemPay`, the trace and EBS R07) restricted to run dates from the business date on (`Newer.laufd >= Pay.laufd`, both sides bounded by the 45-day window) - a re-run is days later, never older. Then GROUP BY company code and status in the database | the payments of the day (≈ 2 M on a peak day) and their later re-runs; result rows = company codes × statuses (tens) |
| Payment lifecycle request stages | worklist `ZCD_PAY_OUTCOME` index **DUE** (DUE_DATE) with VALID_TO open and AUGBL blank | the open / not-paid requests due on the date (thousands) |
| **View payments** (`ZR_CD_PayOfDay`) | as above, rows not aggregated; the request source by AUGBL (index **DOC** of the worklist, current rows only); OData paging (`$top` / `$skip`) - the list never loads the 2 M rows at once | one page |
| **Daily controls** (`ZR_CA_OpsCtlReview`) | `ZCA_OPS_RUN` by STARTED_AT within 33 days (index MOD: AREA, STARTED_AT - the areas come from the covered checks), business date = run start in `CONTROL_TIME_ZONE`; findings by **RUN_ID** (primary key prefix) of the runs of the date; open exceptions by index **OPN** (AREA, DISPOSITION); controls, covered checks and sign-offs are small tables | runs of one day (FMON every 5 min: ≈ 300 per area) and their findings |
| **Open variances** (`ZR_CD_OpsVariance`) | `ZCD_HCK_METRIC` metrics `RC_DIFF_*` (results only, retention `RETENTION_DAYS_HCK_METRIC`), newer measurement anti-join by index **HST** (CHECK_ID, METRIC, DIM1, DIM2, MEASURED_AT), tolerance / expected / actual of the same run by primary key; the break finding by RUN_ID + OBJECT_KEY | group-days × legs (tens per day) |

No bank, G/L or payment engine line is read for the variance card (results of `A_RECON_3WAY`), and no DFKKOP item is read for the lifecycle (the payment run row carries status, method and amount). **VERIFY in QA1:** PlanViz of the lifecycle card at a 2 M-payment day: the DPAYH access must be a range on the primary key and the DOC1R probe an index join, response < 5 s (OVP-14); if the anti-join is planned as a full DPAYH scan, add the DPAYH secondary index on DOC1R + LAUFD (VERIFY-SE11, as §8) or restrict the newer-run side to the business date + 45 days.

## 12. Payment model, service health, process flow and missing-volume reads (2026-11-11)

| Read | Access path | Volume (2 million payments on a peak day) | Fallback / bound |
|---|---|---|---|
| `ZI_CD_PaymFact` (payment model adapter) | `ZI_CD_PayLifeRun`: DPAYH by LAUFD (first key field, primary index) for the 45-day window, newest-run anti-join by DOC1R (index VERIFY-SE11, §11); left joins T001 / TFK042Z (buffered customizing), `ZI_CD_PayMethodCls` (TFK033D ZPMC entries, a few hundred rows), `ZI_CD_PayWorkState` (worklist current rows by AUGBL, index DOC) | 45 days x 200 000-2 000 000 rows, aggregated on HANA; one row per category reaches the UI (`ZR_CD_PaymCube`, `ZR_CD_PaymTrend`) | Cards always carry a date filter (`IsCurrentDay`, `Last30`); the payment list makes the business date mandatory and pages (`$top`); PlanViz V93 |
| Source of a payment without worklist row | **Not read** in this release: DFKKOP-ZZ_FIN_TRANS_NUM -> request log needs the request-log FIN field (V82) and the pre-check 0.8 index; at 2 million payments a day the per-payment link must never be a full scan | - | **Source unknown bucket** (blank source, dimension text "Not resolved"); the payment trace finds the source of one payment by key. When V82 is closed: the link view of the spec (`payment_request`) bounded by the payment documents of the business date (driver = DPAYH of LAUFD), PlanViz before activation |
| Payment -> requests (object page) | DFKKOP by AUGBL (`ZI_CD_PaymReqLink`, one payment document per navigation) | a few rows | Index on AUGBL VERIFY V88; never exposed without a key filter in the UI (navigation only) |
| Request -> payments | DFKKOP by ZZ_FIN_TRANS_NUM (index of pre-check 0.8) | a few rows | Pending with the request section (V82) |
| Requests by received date (trend) | ZCD_PAYM_REQ_LOG by the received date (VERIFY-SE11 field, index to create with pre-check 0.8) | up to 400 000 a day | Until then: requests by due date from the worklist (`ZI_CD_PayLifeCntU`, index DUE) |
| Exceptions per day (`ZI_CD_PaymExcRow`) | ZCA_OPS_FINDING by CREATED_AT / RESOLVED_AT for 45 days, consumer areas | findings, not payments (thousands a day) | Index on CREATED_AT VERIFY (V95 / PlanViz) |
| Service health (`ZI_CD_SvcFind`) | runs of the date (`ZI_CA_OpsCtlRunDay`, 31 days) -> findings by RUN_ID (primary key), as the daily control review (CTL-08) | findings of 31 days | Same plan as `ZI_CA_OpsCtlFind` |
| Process flow (`ZR_CD_PayFlow`) | the payment lifecycle counts (§11) joined with themselves per stage (reached) - aggregated rows only | stages x days x company codes | - |
| Missing-volume checks `B_VOL_*` | generic aggregate, one COUNT per day and group: DPAYH by LAUFD (key), FEBEP by BUDAT (index VERIFY-SE11), FEBKO by AZDAT, ZCD_FMON_FILE by BUSINESS_DATE (index to add if the table grows: VERIFY); history: ZCD_HCK_METRIC index HST with DIM2 IN (6 days) | one aggregate row per group | `HCK_MAX_AGG_ROWS`; a failed query measures nothing (never 0) |

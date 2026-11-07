# 360° payment trace — read-only evidence timeline (Core)

> **First principle:** a stage is only as proven as the record behind it — every line names its table, key and time, and anything not proven stays visibly unproven.
> **Analogy:** a parcel tracking page — each scan shows where and when it happened; a missing scan is shown as missing, never filled in from the expected route.

Objects (package `ZCD_OPS_CORE`, `src/core`): report `ZCD_OPS_PAYMENT_TRACE`, engine `ZCL_CD_OPS_TRACE_ENGINE` (pure logic), read repository `ZIF_CD_OPS_TRACE_DAO` / `ZCL_CD_OPS_TRACE_DAO` (all SQL), types `ZIF_CD_OPS_TRACE_TYPES`; seam `ZCL_CD_OPS_FACTORY=>GET_TRACE_DAO` / `ZCL_CD_OPS_INJECTOR=>INJECT_TRACE_DAO`; messages ZCD_OPS 700–738.

## 1. What it does — and what it never does

Support enters a **FIN ID + source** (primary), or a **clearing / payment document**, or a **cheque number**. The trace shows, per payment attempt, the evidence from the original payment request through SAP processing, file generation, PRISM handoff, bank acknowledgement, settlement / encashment / return, payment engine clearing and G/L transfer.

It **only reads**. It posts, reverses, clears, resets nothing; starts or reruns no business job; removes no lock; moves or re-sends no file; changes no interface, payload or integration routing; writes no business table. The interface `ZIF_CD_OPS_TRACE_DAO` has no write method; the engine and the report write nothing — not even to the suite's own stores (handover notes: §8, proposed).

## 2. Stages

Rows are grouped by **attempt**: attempt 0 holds the request, the open item(s) and the clearing-reset history; attempts 1..n are one per clearing reference (historical ones first, by reset date; then the current one; then an unpaid item).

| # | Stage | Source (table) | Key / join | Evidence shown (VERIFIED) |
|---|---|---|---|---|
| 1 | REQUEST | `ZCD_PAYM_REQ_LOG` (configured `TRACE_SRC_REQUEST`) | FIN number (+ SOURCE) | Row with `ZZ_STATUS = SUCCESS` (never the highest COUNTER): key FIN / source / counter, date, time; member number masked |
| 2 | SAP_ITEM | `DFKKOP` | `ZZ_FIN_TRANS_NUM = FIN` (or `AUGBL` = entered document) | OPBEL / OPUPK / FIN, posting date; partner checked against `BUT000-BPEXT = ZZ_MEMBER_NO` (with source first, then without) |
| 3 | CLEAR_HISTORY | configured `TRACE_SRC_HISTORY` (candidate `DFKKRAPT`) | item OPBEL | Every earlier clearing reference with reset date / time; "no earlier clearing" when the source answered with no row |
| 4 | PAYMENT | `DPAYH` (ACH/wire), `DFKKCR` (cheque, method in `TRACE_CHECK_METHODS`) | `DOC1R = clearing reference` | Run LAUFD / LAUFI / DOC1R and `ZZ_PAYMENT_STATUS`; cheque ZTNUM / house bank / account |
| 5 | FILE_GENERATED | configured `TRACE_SRC_REGUT` (`ZCDT_REGUT`) | DPAYH LAUFD (+ LAUFI) | File reference, date, time — **only** through the configured, DDIC-validated register |
| 6 | PRISM_HANDOFF | `ZCD_FMON_FILE` / `ZCD_FMON_EVENT` | normalised file reference (digest for long names, A100), business date ± `TRACE_BANK_LOOKBACK_DAYS` | Event SENT_TO_PRISM / FORWARDED_TO_BANK, UTC time stamp |
| 7 | BANK_ACK | configured `TRACE_SRC_ACK` (payment level, disbursements), else `ZCD_FMON_EVENT` (file level) | clearing reference / file | ACK row or ACK_RECEIVED event (FAILED on NACK / `TRACE_ACK_NACK_VALUES`); NOT_APPLICABLE for methods in `TRACE_NO_ACK_METHODS` |
| 8 | SETTLEMENT | `FEBEP`; `DFKKRP` (returns lot, `DFKKRK-STARS`); `ZCD_ACH_RTRV_LOG`; configured `TRACE_SRC_CHQ_HIST` (`ZCD_CHECK_HIST`) | `CHECT = AUGBL` (E G H I J K L) or `CHECT = ZTNUM` (C) **on a statement of the cheque's house bank account** (FEBKO BUKRS / HBKID / HKTID = company code of the attempt + DFKKCR-HBKID / HKTID; shared rule `ZCL_CD_OPS_CHEQUE_LINK`, design review 2026-11-07: a line of another account is never the cheque's, a line fitting several cheques of the attempt is one AMBIGUOUS row `MULTIPLE_MATCHES`); `SELW1 = AUGBL`; retrieval log `AUGBL` | Bank line KUKEY / ESNUM / CHECT and posting date (encashment for cheques); return or retrieval = FAILED, every returns lot item with its **return reason `DFKKRP-RLGRD`** (code only — no text table is read; VERIFY-SE11), for every clearing reference incl. the historical ones of reversed items; items of one clearing reference with different RLGRD add one AMBIGUOUS row (`RETURN_REASON_AMBIGUOUS`) listing all reasons; cheque status, terminal 3/4/9 = FAILED |
| 9 | NOC | `DFKKNRP` (NOC lot items; shared EBS read `GET_NOC_ITEMS`) | `INFOF` (CHAR 50, **not a key**) = the attempt's clearing document (AUGBL) or a payment reference of the attempt (FIN of its items, cheque number) — each read as stored and without leading zeros, matched after condensing / removing leading zeros of all-digit values; exact INFOF content VERIFY-SE11 | Lot KEYN1, item POSNA, **NOC reason `FLGRD`** and the INFOF value. **Informational** (account data change, not a return): VERIFIED when found, NOT_APPLICABLE (`NO_NOC_ITEM`) when not — never MISSING; several items with different FLGRD or the row cap = AMBIGUOUS (all listed). NOC rows never set the first gap and never change the verdict |
| 10 | FICA_CLEARING | `DFKKOP` (current) / history source (historical); `BSEG` | item + AUGBL; BSEG by document key with `XREF2 = AUGBL` | Clearing date; clearing-account line of the G/L transfer document (not for method C) |
| 11 | GL | `DFKKKO` → `DFKKSUMC` → `BKPF` | `DFKKKO-FIKEY = DFKKSUMC-FIKEY = BKPF-AWKEY`, `AWTYP = TRACE_GL_AWTYP` (FKKSU), same BUKRS, `STBLG` blank | G/L document BUKRS / BELNR / GJAHR, entry date / time |

## 3. Statuses and verdict

| Status | Meaning |
|---|---|
| VERIFIED | Exactly one record proves the stage; source table, record key and timestamp shown |
| MISSING | The source was read and holds no record (e.g. no bank line yet, no SUCCESS row) |
| AMBIGUOUS | More than one candidate (two SUCCESS rows, two bank lines, competing partners, request partner owns none of the items, row cap reached) — **all** are listed, none is picked |
| UNAVAILABLE | Could not be checked: source not configured, not readable (DDIC / approval / S_TABU_NAM), no link key from an earlier stage, file not in file monitoring, or company code **not authorised** (shown as "not authorised", never as missing) |
| FAILED | Positive evidence of failure: NACK, return lot, retrieval, terminal cheque status |
| NOT_APPLICABLE | Stage does not exist for this payment (e.g. no ACK for the method) — with reason |

There is no PENDING: no deterministic per-stage rule exists yet (proposed: SLA from the FMON SLA table). The **first missing / failed milestone** of every attempt is flagged (`FIRST_GAP`), and the result names the first one of the request and current attempts. Verdict: `NOT_FOUND` (nothing for the keys) › `FAILED` › `AMBIGUOUS` › `INCOMPLETE` (any MISSING / UNAVAILABLE, or no current attempt) › `COMPLETE`. Historical attempts are shown as evidence and do not decide the verdict; NOC rows are information only and are ignored by the verdict and the first gap. **Incomplete evidence can never produce COMPLETE.**

## 4. The two lookup paths (verified against the repository)

### 4.1 FIN ID + source

| Fact | Where it comes from (repository) |
|---|---|
| `ZCD_PAYM_REQ_LOG` FIN number = `DFKKOP-ZZ_FIN_TRANS_NUM`; paid = `AUGBL` filled, `AUGDT` | `src/hck/zcl_cd_hck_c_prq_cancel.clas.abap:15-17, 93-99`; `docs/USAA_Known_Tables.md` §1 |
| Status field `ZZ_STATUS`, SUCCESS row, never the highest COUNTER; source field `SOURCE` | `docs/USAA_Known_Tables.md` §1; `docs/DEVELOPMENT_STANDARDS.md` §1; HCK check `:70` (SOURCE spec key) |
| Partner `ZZ_MEMBER_NO = BUT000-BPEXT`, with SOURCE first, then without (legacy PCLM) | `docs/DEVELOPMENT_STANDARDS.md` §1 |
| Table / field names of the request log are configuration, validated against the DDIC | HCK value query `src/hck/zcl_cd_hck_value_query.clas.abap`; FMON reader `src/fmon/zcl_cd_fmon_query.clas.abap:91` (validate), `src/fmon/zcl_cd_fmon_dao.clas.abap:315, 399-410` (approval + S_TABU_NAM) |

Implementation: `ZCL_CD_OPS_TRACE_ENGINE` `trace_request` (`:470`, rule at `:486`), `resolve_partner` (`:531`), `check_items` (`:559`). Two SUCCESS rows → both AMBIGUOUS; a failed retry after the SUCCESS row is ignored; partner without source is shown as `PARTNER_WITHOUT_SOURCE`; a request partner that owns none of the FIN's items → `PARTNER_MISMATCH` (AMBIGUOUS, not traced further).

### 4.2 Separate clearing-reference lookup for reversed items

After a reversal or clearing reset, `DFKKOP` of the request item carries a **new** AUGBL (or none), while the bank and G/L evidence (`FEBEP-CHECT`, `BSEG-XREF2`) still carries the **original** clearing reference. The trace therefore:

1. reads the item's historical clearing references from the clearing-reset history (`TRACE_SRC_HISTORY`, candidate `DFKKRAPT`; key = item OPBEL, REF = historical clearing document, DATE / TIME = reset date / time — **field names VERIFY-SE11**, validated against the DDIC at run time through the FMON reader);
2. traces payment, file, ACK, settlement / return and G/L **for every clearing reference** (current + historical), one attempt each — a reissue is a later attempt (`trace_history` `:636`, `build_attempts` `:726`);
3. treats reversal evidence without a history row as **`REVERSAL_HISTORY_MISSING`** (MISSING), and an unconfigured / unreadable history source as UNAVAILABLE — with reason `REVERSAL_HISTORY_MISSING` when the item shows reversal evidence. Neither is ever a pass; an unconfigured history keeps every trace INCOMPLETE, because the absence of an earlier attempt is then unproven.

Reversal evidence used: `DFKKOP-AUGRD` = `05` (constant `ZIF_CD_OPS_TRACE_TYPES=>GC_REVERSAL_AUGRD`; 05 is the only reversal reason — user decision 2026-11-07, no parameter; then the current AUGBL is the reversal, not a payment attempt), or `DFKKKO-STBEL` set on the current clearing document. Both are standard fields **not used elsewhere in this repository — VERIFY-SE11**. `BKPF-STBLG` (used by `src/hck/zcl_cd_hck_dao.clas.abap:532`) excludes reversed G/L documents.
**Limitation:** a clearing reset followed by a re-clearing that leaves no reversal mark on the item is visible only through the history source. Proposed extra indicator (not built): `DFKKOP-XRAGL` (clearing reset), VERIFY-SE11.

### 4.3 Reused access paths (no copies, no new dynamic SQL)

| Read | Reused from |
|---|---|
| DPAYH by DOC1R (`ZZ_PAYMENT_STATUS`, proposal runs excluded via `XVORL`) | `ZCL_CD_EBS_SAP_DAO=>GET_PAYMENTS` (`src/ebs/zcl_cd_ebs_sap_dao.clas.abap:85-98`) |
| DFKKCR by ZTNUM (house bank, optional company-code field) | `GET_CHECKS` (`:157`) |
| DFKKRP by SELW1 with DFKKRK-STARS and the return reason RLGRD | `GET_RETURN_ITEMS` (`:56`) |
| DFKKNRP by INFOF with the NOC reason FLGRD (capped in the trace DAO at `TRACE_MAX_ROWS` + 1, as the cheque read) | `GET_NOC_ITEMS` (`:71`) |
| ZCD_ACH_RTRV_LOG by AUGBL, status field `EBS_RTRV_STATUS_FIELD` (DDIC-validated) | `GET_RETRIEVALS` (`:136`) |
| Configured sources (request log, history, ZCDT_REGUT, ACK, cheque history, BUT000 source field) | FMON reader: `ZCL_CD_FMON_QUERY=>VALIDATE` + `ZCL_CD_FMON_DAO=>READ_LEGACY` (DDIC, `ZCD_FMON_TABWL`, `S_TABU_NAM` 03, bound values) |
| FMON file correlation key / digest | `ZCL_CD_FMON_UTIL=>NORMALIZE_REF` / `IS_DIGEST_REF` / `CANONICAL_NAME` (A100) |
| G/L transfer rule (AWTYP, BUKRS, STBLG) | `ZCL_CD_HCK_DAO=>GET_FIKEYS_WITHOUT_GL` (`src/hck/zcl_cd_hck_dao.clas.abap:517-533`, A43) |

The trace DAO's own static reads: DFKKOP (by FIN, by AUGBL), DFKKKO, DFKKCR by DOC1R, FEBEP by CHECT + BUDAT, ZCD_FMON_FILE (BUSINESS_DATE window + FILE_REF), ZCD_FMON_EVENT, DFKKSUMC, BKPF, BSEG (by document key only), TFK042Z/T001, BUT000 by BPEXT. Every read is keyed and capped (`TRACE_MAX_ROWS`, default 50); no LIKE, no full scans by XREF2.

Shared with the morning report (2026-11-07): the in-flight check `A_INFLIGHT` (`HCK_MORNING_REPORT.md` §7b) reads document headers (reversal STBEL), payment runs (DPAYH status), returns (with the item amount DFKKRP-BETRW, VERIFY-DDIC), cheques by DOC1R and bank lines by CHECT through this repository (`ZCL_CD_OPS_FACTORY=>GET_TRACE_DAO`) instead of its own SQL; `GET_CHECKS_BY_DOC` therefore also reads the cheque status `DFKKCR-STATE` (confirmed 2026-11-07: B cashed, V voided, blank open; replaces the encashment date BANCD) and `GET_BANK_LINES` the code of the line (FEBEP-VORGC / VGEXT, as the EBS line read).

## 5. Parameters (framework `ZCA_PARAM`, area `CD_OPS` — maintained in the app *Parameter areas* (`ZUI_CA_PARAM_O4`); definitions and delivered defaults: `config/param_definitions.csv`)

| Parameter | Default | Meaning |
|---|---|---|
| `TRACE_MAX_ROWS` | 50 | Row cap per read; reaching it makes the stage AMBIGUOUS (`ROW_CAP_REACHED`) |
| `TRACE_SRC_REQUEST` | — | `TABLE=ZCD_PAYM_REQ_LOG;KEY=<FIN field>;KEY2=SOURCE;REF=COUNTER;STATUS=ZZ_STATUS;DATE=..;TIME=..;INFO=ZZ_MEMBER_NO` |
| `TRACE_SRC_HISTORY` | — | `TABLE=DFKKRAPT;KEY=<item doc>;REF=<historical clearing doc>;DATE=<reset date>;TIME=<reset time>` |
| `TRACE_SRC_REGUT` | — | `TABLE=ZCDT_REGUT;KEY=<LAUFD field>;KEY2=<LAUFI field>;REF=<file key = FMON source REGUT FILE_KEY_FIELD>;DATE=..;TIME=..` |
| `TRACE_SRC_ACK` | — | Payment-level ACK, e.g. `TABLE=ZCD_ACH_ACK;KEY=<payment key>;STATUS=..;DATE=..;TIME=..` (blank = file level from FMON) |
| `TRACE_SRC_CHQ_HIST` | — | `TABLE=ZCD_CHECK_HIST;KEY=<cheque no>;STATUS=ZECT_STATUS;DATE=..;TIME=..` |
| `TRACE_BP_SOURCE_FIELD` | — | BUT000 field carrying the source (blank = partner read without source only) |
| `TRACE_PRQ_SUCCESS` | SUCCESS | Success value of `ZZ_STATUS` |
| `TRACE_GL_AWTYP` | FKKSU | AWTYP of the payment engine G/L transfer |
| `TRACE_CHECK_METHODS` | C | Cheque payment methods |
| `TRACE_NO_ACK_METHODS` | — | Methods without bank ACK (BANK_ACK = NOT_APPLICABLE) |
| `TRACE_ACK_NACK_VALUES` | NACK,REJECTED,R | ACK status values that mean rejected |
| `TRACE_CHQ_FAILED` | 3,4,9 | Terminal cheque statuses (ZECT_STATUS) |
| `TRACE_BANK_LOOKBACK_DAYS` | 5 | Bank lines from clearing date minus n days; FMON file window ± n days around LAUFD |
| `EBS_RTRV_STATUS_FIELD` | (EBS) | Shared with EBS: status field of ZCD_ACH_RTRV_LOG |

Every configured table also needs a `ZCD_FMON_TABWL` row (table + fields or `*`) and `S_TABU_NAM` 03 for the users; otherwise the stage is UNAVAILABLE (`SOURCE_NOT_READABLE`), never VERIFIED.

## 6. Access and masking

- Report: `ZCD_OPS` ACTVT 03, `ZCD_PE_AREA` CORE (message 041 otherwise).
- Engine: every open item is checked per company code (`ZCD_OPS` 03, BUKRS). An unauthorised item is one row `UNAVAILABLE / NOT_AUTHORISED` with no key, date or clearing reference; it is not traced further and never appears as MISSING.
- Configured reads additionally need `S_TABU_NAM` 03 (FMON reader boundary).
- Member numbers are masked to their last four characters (`ZCL_CD_OPS_TRACE_ENGINE=>MASK`). Bank account numbers are not read.

## 7. Operating boundary (excluded by design)

Posting, reversal, clearing or reset; business job starts or reruns; lock removal; file movement or retransmission; changes to interfaces, payloads, message contracts or integration routing; any write to business tables. Recovery stays with the authorised operator under the existing runbook.

## 8. Proposed, not built

- **Handover / support notes:** the core exception store (`ZCD_OPS_FINDING` / `ZCD_OPS_EXC_HIST`, owned-exceptions app) records dispositions of *findings*; a trace is not a finding, so storing a note would need a new finding type or note table. Proposed: an action "Record trace finding" that writes one finding (check code `PAYMENT_TRACE_GAP`, object = FIN / clearing ref, masked summary) through `ZIF_CD_OPS_STORE`, so the existing assign / resolve / handover flow applies. Today the copyable summary is message 700 plus the ALV export.
- **File reference as input:** cheap via `ZCD_FMON_FILE` (reference → events) but the reverse link file → payments needs the ZCDT_REGUT link confirmed first.
- **PENDING status** from FMON SLA rows; **XRAGL** reset indicator (§4.2).

## 9. VERIFY-SE11 / target QA list

| Item | What to confirm |
|---|---|
| `DFKKOP-PYMET`, `AUGRD`, `AUGDT`, `ZZ_FIN_TRANS_NUM` index | Fields exist; reversal clearing reason value(s); secondary index on ZZ_FIN_TRANS_NUM (performance) |
| `DFKKKO-STBEL`, `CPUDT`, `CPUTM` | Reversal document field on the clearing document header |
| `DFKKRAPT` | Table purpose (clearing reset history), the item key, historical clearing document, reset date / time fields → `TRACE_SRC_HISTORY` |
| `ZCD_PAYM_REQ_LOG` | FIN field, date / time fields, `ZZ_MEMBER_NO` |
| `BUT000` source field and BPEXT index | `TRACE_BP_SOURCE_FIELD` |
| `ZCDT_REGUT` | LAUFD / LAUFI and file key fields; that the file key equals the FMON REGUT source FILE_KEY_FIELD |
| ACK tables (`ZCD_ACH_ACK`, `ZCD_WIRE_ACK`) | Payment key = clearing reference? status values for NACK |
| `ZCD_CHECK_HIST` | Cheque number, status, date / time fields |
| `DFKKRP-RLGRD` | Return reason field and length (3); a text table for the reason code (not read — code only) |
| `DFKKNRP-INFOF`, `FLGRD`; INFOF index | INFOF holds AUGBL (with leading zeros?) or which payment reference (FIN, cheque number, other); FLGRD length; a secondary index on INFOF for volume |
| `DFKKCR-RWBTR`, `CRSTATUS`; `FEBEP-KWBTR`, `VORGC`, `VGEXT`, CHECT index; `DFKKRP-BETRW` | As EBS (VERIFY-DDIC); `DFKKCR-STATE` confirmed (morning report check `A_INFLIGHT`); whether EBS / trace should read STATE instead of CRSTATUS is open (VERIFY); FEBEP read by CHECT needs an index (performance) |
| `TFK042Z` key LAND1 / ZLSCH via `T001-LAND1` | Collection vs disbursement for the ACK level |
| `BKPF-CPUDT/CPUTM/STBLG`, `DFKKSUMC-BUKRS` | As HCK (VERIFY-DDIC) |
| Dynamic WHERE `IN @LT_IN` against DATS key (REGUT LAUFD) | FMON reader with a date key column (VERIFY-ADT) |
| Authorisations | ZCD_OPS 03 CORE + BUKRS; S_TABU_NAM 03 for every configured table |
| Performance | Peak-volume run of 20 traces (FIN, clearing doc, cheque) in QA1 with ST05 |

## 10. Tests and QA cases

ABAP Unit (`ZCL_CD_OPS_TRACE_ENGINE` local test class `ltc_trace`, LTD read-repository double through `ZCL_CD_OPS_INJECTOR`):

| Test | Proves |
|---|---|
| `ach_full_chain_is_complete` | Normal ACH disbursement: every stage VERIFIED in timeline order, verdict COMPLETE |
| `every_verified_row_has_source` | Each VERIFIED stage names source table, record key and date; FEBEP key KUKEY/ESNUM/CHECT |
| `cheque_encashed_by_ztnum` | Method C: DFKKCR by DOC1R, cheque status, encashment FEBEP by ZTNUM; no XREF2 line |
| `cheque_other_account_missing` | Method C: the cheque number on a statement of another house bank account is not the encashment - settlement MISSING, never COMPLETE |
| `reissue_traces_two_attempts` | Reversed / reissued: two attempts; bank line and return found under the ORIGINAL clearing ref |
| `reversal_without_history` | Reversal evidence, no history row → REVERSAL_HISTORY_MISSING, first gap, never COMPLETE |
| `reversal_history_unavailable` | Reversal evidence, history not configured → UNAVAILABLE with REVERSAL_HISTORY_MISSING |
| `two_success_rows_ambiguous` | Two SUCCESS rows → both AMBIGUOUS, FAILED row hidden, verdict AMBIGUOUS |
| `success_row_not_last_counter` | SUCCESS counter 1 wins over FAILED counter 3 |
| `two_bank_lines_ambiguous` | Two FEBEP candidates → both listed AMBIGUOUS |
| `sent_without_ack_gap_ack` | Sent to PRISM, no ACK → first gap BANK_ACK, INCOMPLETE |
| `nack_fails_the_trace` | NACK → FAILED |
| `ack_without_bank_line_gap` | ACK but no statement line → first gap SETTLEMENT, INCOMPLETE |
| `history_unconfigured_unavail` | History source not configured → UNAVAILABLE, INCOMPLETE |
| `regut_unconfigured_unavail` | ZCDT_REGUT not configured → FILE_GENERATED UNAVAILABLE, never VERIFIED; PRISM no link |
| `chq_hist_unconfigured_unavail` | Cheque history not configured → UNAVAILABLE row, INCOMPLETE |
| `unauthorised_not_missing` | Unauthorised company → NOT_AUTHORISED, no key, nothing MISSING, not COMPLETE |
| `partner_mismatch_ambiguous` | Request partner owns none of the items → AMBIGUOUS, not traced |
| `partner_without_source_noted` | Partner found only without source → VERIFIED with PARTNER_WITHOUT_SOURCE |
| `clearing_doc_input_traces` | Clearing document input finds item and request through its FIN |
| `unknown_fin_is_not_found` | Unknown FIN → NOT_FOUND |
| `member_number_is_masked` | Member number never shown unmasked |
| `return_shows_return_reason` | Returns lot item on the clearing: FAILED with its return reason RLGRD; verdict FAILED |
| `historical_return_has_reason` | Reversed item: the return under the historical clearing reference shows its RLGRD |
| `two_return_reasons_ambiguous` | Two returns lot items with different RLGRD → one AMBIGUOUS row listing both, both items shown |
| `noc_found_by_clearing_doc` | NOC item with INFOF = AUGBL → VERIFIED, DFKKNRP, KEYN1 / POSNA, FLGRD |
| `noc_found_by_payment_ref` | NOC item with INFOF = payment reference (FIN) → VERIFIED |
| `no_noc_is_not_applicable` | No NOC item → NOT_APPLICABLE (`NO_NOC_ITEM`), never MISSING, no gap |
| `noc_never_changes_verdict` | Two NOC items with different FLGRD → AMBIGUOUS rows, verdict still COMPLETE, no first gap |

OSQL (`ZCL_CD_OPS_TRACE_DAO`, `ltc_trace_dao`): items by FIN and row cap, FEBEP by reference and date, DFKKCR by DOC1R, FMON file in the business-date window, BKPF by AWTYP/AWKEY, BSEG by key and XREF2, FOR ALL ENTRIES guard, NOC items by INFOF capped at the row cap + 1 (`noc_items_by_infof_capped`). The full-chain test now also lists the NOC row (NOT_APPLICABLE without a NOC).

QA1 cases (L1/L2 reproduce search → correlate → inspect → hand off): one PCLM claims ACH payment end to end; one cheque (mailed, encashed); one collection (file-level ACK); a reissued payment after a return; a reversed item with and without history; a FIN with two SUCCESS rows; a payment sent but not acknowledged; a user without the company code. For each, compare with SE16 / FPL9 / FEBAN and confirm that running the trace changed no business table, job, lock, file or interface (ST05 shows SELECT only).

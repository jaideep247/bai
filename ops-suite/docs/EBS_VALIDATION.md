# EBS Validation — BAI2 and CAMT bank statements

> **First principle:** every line on a bank statement is either matched to a payment-engine record, posted by an approved rule, or held as an owned exception — never silently parked in suspense.
> **Analogy:** a customs hall — every parcel (statement line) is scanned against its manifest (bank transaction code map); parcels without a manifest entry go to the held-goods room with a ticket, they are never waved through.

---

## Part A — Business & Operations

### A0. Operating model (decision 2026-11-06)

> **First principle:** the validation reads what SAP has already done — so it runs only after SAP has finished doing it.
> **Analogy:** an auditor counts the till after the shop has closed; counting while customers are still paying produces "missing" money that is only in the queue.

`ZCD_EBS_VALIDATE` is a **post-posting detective control**. Control-M starts it as the last job of the bank-statement chain, by job dependency, not by clock time:

```
bank statement import (FF_5 / FEBKO, FEBEP)  →  posting job (FEBP)  →  payment clearing job  →  ZCD_EBS_VALIDATE
```

It **reports findings and never stops a posting**: by the time it runs every line is already posted (or deliberately left unposted). It changes no business data, starts no job and takes no lock on a standard table. The suite is read-only towards production: it has no pre-posting entry, no posting gate and no release of lines; enforcement is a later phase with its own design.

**What a finding means for a posted line, and who corrects it.** The suite does none of the corrections below; an authorised operator does them under the operations runbook with the standard transaction.

| Finding | What it means after posting | Correction route (operator, runbook) | Owner |
|---|---|---|---|
| **R14 UNMAPPED_BTC** | No posting rule fired — the line is still open in post-processing | Map the code (ZCD_BTC_MAP, §B6a), then post the line from FEBAN (reprocess) | Payment engine support + Treasury |
| **R07 / R07C / R07L / R07R / R21** not found or wrong status | The line posted, but the payment engine record it should match (payment run, cheque, retrieval, returns lot, lookup table) is missing or in another status | Clarify the payment lot in FPCPL, or reverse and repost the line with the correct reference | Disbursement ops |
| **R08 / R12** amount or total differs | Posted amount differs from the cheque register | Clarify with the bank; reversal / repost if the posting is wrong | Disbursement ops |
| **R19 FI_DOC_NOT_FOUND / FI_DOC_NOT_CLEARED / NOT_POSTED** | Posting flags complete but no FI document, or the document is not cleared after the clearing job | Check the clearing job; clarify in FPCPL; FEBAN reprocess for a line without document | Payment engine support |
| **R18 GL_NE_CLOSING** | Bank G/L balance differs from the statement closing after posting | Look for open lines in FEBAN and manual postings on the bank G/L; reconcile | Treasury / finance |
| **S01 / S02 / S03 / S07 / S12** | The statement itself is incomplete, unbalanced, out of sequence or a duplicate — and has been posted | Request the missing / corrected statement; a duplicate that was posted is reversed under the runbook | Treasury |
| **S10 ENTRIES_NOT_ACCOUNTED** | Posting areas complete but no FI document and not blocked | FEBAN post-processing | Payment engine support |
| **S13 POSTING_INCOMPLETE** | A predecessor job had not finished, or lines that should post were left unposted — the posting-dependent rules were **not evaluated** | Runbook §5c: check the predecessor jobs, re-run `ZCD_EBS_VALIDATE` after them | Payment engine support |

**Posting state of a line (FEB source).** The FEB source reads, per FEBEP item, the posting-area completion flags named in `EBS_FEB_POSTED_FIELDS` (default `VB1OK,VB2OK` — posting area 1 / 2 posted, **confirmed 2026-11-07**; each name is checked against the DDIC, an unknown name stops the run with message 051; `NONE` switches the read off). Every flag X = **posted** (P), otherwise **open** (O). The engine then marks a line **POSTING_OPEN** when it is open, its map row is not `NOT_POSTED` (sweeps 275 / 575 are never expected to post, A26) and it is not blocked (R14 lines are reported by R14).

**Posting-dependent rules (ZCD_EBS_RULE_DEF-NEEDS_POSTING).** Rules that read SAP evidence of the posting or clearing:

| Rule | Why it needs the posting | Seed |
|---|---|---|
| R07 | DPAYH status such as RETURNED is set by the return / clearing processing | X |
| R07L | the 166D chain needs the returns-lot item created when the return is posted (PARAM3 LOT); AF statuses follow the bank confirmation | X |
| R07R | returns lot item and lot status come from posting the return | X |
| R05 | FEB source: the return / NOC reason is read from the returns lot (DFKKRP-RLGRD) / NOC lot (DFKKNRP-FLGRD), created by return / NOC processing (bank file: the file's own code, unchanged) | X |
| R19 | FI document (FEBEP-BELNR) exists / is cleared | X |
| R18 | the bank G/L balance contains the statement only after posting | X |
| R21 | a configured lookup may read posting evidence — conservative default; set blank in the registry for a lookup on pre-posting data | X |
| S10 | judges completeness from the FI document number | X |
| R07C, R08, R12 | read the cheque register (DFKKCR), written by the payment run before the statement | — |
| S01–S05, S07, S09, S12, R01–R04, R09, R10, R15, R22 | structure, balances, duplicates, sign, value date, mapping, import interpretation | — |

**One posting-open definition, shared (2026-11-07).** `posting_open` = posting state O, not NOT_POSTED, not blocked is `ZCL_CD_EBS_STMT_EVIDENCE=>IS_POSTING_OPEN`, used by the engine (S13) and by the statement evidence that file monitoring reads (`ZIF_CD_EBS_STMT_EVIDENCE`, FEB adapter, BAI 10:00 deadline — `FMON_FILE_MONITORING.md` §B1b). The evidence is built from this area's own pipeline (ZCL_CD_EBS_SRC_FEB with `POSTED_FIELDS( )`, ZCL_CD_EBS_PE_SCOPE, ZCL_CD_EBS_BTC_RESOLVER) — no second FEBKO / FEBEP read. Dependency FMON → EBS only. File monitoring counts a blocked unposted line as not posted (`iv_count_blocked`); S13 does not (the line has its own UNMAPPED_BTC finding).

For a POSTING_OPEN line these rules are **not evaluated** (a line rule does not receive the line; a statement rule does not receive the statement that holds it). The line is counted as **unevaluated** — never passed, never failed (a B / E finding of a rule that did run still counts it as blocked / failed) — and reported in the run message (message 542). Rule **S13** raises **one POSTING_INCOMPLETE per statement** with the number and total of those lines (seed W / NOTIFY). A run with such lines is **never green** (at least amber, whatever S13 is configured with), and the exception carry-forward leaves the open exceptions of those lines and their statement untouched — a check that did not run never resolves anything. Every rule that does not depend on the posting still runs on the line.

**Bank file source (BAI2 / CAMT before import).** The posting state is unknown by definition and is never invented: no line is POSTING_OPEN, S13 never reports, and the posting-dependent rules run exactly as before — R19 reports NOT_POSTED for a line without document unless PARAM3 = OPTIONAL, R18 compares the G/L balance as it is before the statement is posted, S10 skips file statements, R07* / R21 read the payment engine records as they are. Use the file source for structural checks before import; the posting-dependent results of the batch run come from the FEB source.

### A0a. Scope — payment engine accounts only (user decision 2026-11-06)

> **First principle:** the suite validates the bank lines of the payment engine — a statement that also carries other accounts' lines is not the payment engine's to judge.
> **Analogy:** a sorting office checks only the bags addressed to its own district; a bag with mixed addresses is set aside unopened, counted, and never reported as damaged.

**Which account a line belongs to.** FEBEP-XBLNR carries the payment engine bank account: **bank text** (letters such as JPMC, BOA, PNC) + **10-character account** + **counter**, e.g. `JPMC8XX1174412334` → account `8XX1174412`, counter `334` (confirmed by the user 2026-11-06, `USAA_Known_Tables.md` §1). Rule, in one place: `ZCL_CD_EBS_PE_SCOPE=>PE_ACCOUNT_FROM_XBLNR` — remove the leading letters (PCRE `^[A-Za-z]+`), condense, upper case, first 10 characters. Pattern and length are the constants `ZIF_CD_EBS_TYPES=>GC_PE_ACCOUNT`; the dashboard view `ZI_CD_EbsLineAcct` uses the same values as literals (CDS cannot read an ABAP constant) — **a change to one is a change to both** (and to the CDS test data). A shorter rest is taken as it is (it matches no 10-character account); a blank XBLNR or one with letters only gives no account.

**Which accounts are payment engine accounts.** The active rows of `ZCD_EBS_ACCT`, column **ACCOUNT_NO** = the 10-character account as derived from XBLNR (EBS configuration app, field *Payment engine account (XBLNR, 10 characters)*). Compared condensed and in upper case (the dashboard: leading blanks removed, upper case). Two active rows with the same account number are one account.

**What is in scope.** An imported statement (FEB source) is validated **only when it has at least one line and every line's account is a payment engine account**. Otherwise it is **out of scope** and skipped entirely before validation (`ZCL_CD_EBS_ENGINE`, per package):

| Out-of-scope statement | Behaviour |
|---|---|
| Mixed: any line of another account | No statement rule, no line rule (also not S04 or R14), no posting-state check, **no finding**, not counted in the entries |
| A line with a blank or unparseable XBLNR | Same — the statement is not a payment engine statement |
| No lines at all | Same (decision: nothing proves it is a payment engine statement) |
| Exceptions of earlier runs for it or its lines | **Stay open** — not reconciled (as POSTING_OPEN entries: a statement that was not evaluated never resolves anything) |
| Counting | `ZCL_CD_EBS_ENGINE=>TY_RESULT-OUT_OF_SCOPE` and the run message (ZCD_OPS 546 *n statements out of scope (lines not all payment engine accounts)*). `ZCD_OPS_RUN` has no field for it; the message carries it |
| NO_DATA | Only statements **in scope** count as evaluated. A run whose statements were **all out of scope** evaluated nothing: status **N (NO_DATA), RAG grey, never green**, with the out-of-scope count in the run message — an empty or wrong `ACCOUNT_NO` configuration therefore shows up instead of looking like a clean day. `EBS_EMPTY_FEED_OK` = X declares such a day as expected (as for an empty feed) |
| Dashboard | Not shown (`Dashboard_EBS_Validation.md` §2: same rule in CDS) |

**S04 (account configured)** stays: it checks the in-scope statement's house bank account (company code, house bank, account ID) and currency against `ZCD_EBS_ACCT`; it never sees an out-of-scope statement, so it reports only a payment engine statement whose house bank account row is missing or has another currency.

**Bank file source (BAI2 / CAMT before import).** XBLNR is not a field of the bank file — SAP fills FEBEP-XBLNR during the import (bank-specific interpretation), and neither the BAI2 16 record (bank / customer reference) nor CAMT (`EndToEndId`, `AcctSvcrRef`, …) carries a confirmed equivalent. File-source runs are therefore **scoped by the account configuration as before** (S04 on the file's account, matched by house bank or by ACCOUNT_NO = the account of the 03 record / `Acct/Id`); the XBLNR rule applies to the FEB source and the dashboard. VERIFY with a sample file of each bank whether the 03 / `Acct/Id` account equals the 10-character payment engine account; if not, file-source S04 needs its own account column.

### A1. What it does
1. **Receives** a bank statement either as a file before import (BAI2 from JPMC/BOA, CAMT.053 statements, CAMT.054 notifications) or after FF_5/FEBP import (FEBKO/FEBEP).
2. **Checks the statement** as a whole (S-checks): balances chain from the previous statement, the statement adds up, numbers have no gaps, the account is known, nothing is a re-delivery, bank control totals agree.
3. **Classifies every line** by its bank transaction code (BAI2 type code or CAMT Domain-Family-Sub-family) into a business category (C01 ACH collection … X01 unmapped).
4. **Validates each line** with the rules configured for its category: right direction, right currency, reference present, matches the payment run / check register / returns lot / ACH retrieval, amounts agree, not a duplicate.
5. **Records** every problem as an owned exception with a due date, and **alerts** according to the alert rules.
6. **Marks as blocked** any line that must not post — unmapped codes, NOC entries, failed integrity checks (severity B or action BLOCK) — so the operator corrects it; the run reports and never stops a posting (§A0).

### A2. Category reference (requirements baseline matrix)

| ID | Category | CAMT | BAI2 | Expected processing |
|---|---|---|---|---|
| C01 | ACH collection settlement | PMNT-IDDT-PADD | 165 | Auto-clear vs debit memo items |
| C02/C03/C04 | ACH collection return / reject / reversal | PMNT-IDDT-UPDD · AREV | 557 · 561 · 558 | Returns lot (FP09) + return reason |
| D01 | ACH disbursement settlement | PMNT-ICDT-ACDT | 447 | Auto-clear vs payment run |
| D02/D03/D04 | Disbursement return / reject / reversal | PMNT-ICDT-ARET · AREV | 257 · 261 · 258 | Re-credit, notify source |
| I01/I02 | Inbound ACH receipt / return | PMNT-RCDT-ACDT · ARET | 142 | Auto-clear, else clarification |
| W01–W06 | Wires out / in / returns | PMNT-ICDT/RCDT-DMCT·XICT · RRTN | 495 · 195 · 266 | Match wire ack; clarification |
| K01/K02 | Check paid / returned | PMNT-ICHQ-CCHQ · CQRV | 475 · 255 | Match check register |
| K03–K05 | Deposit / deposit return / redeposit | PMNT-RCHQ-CCHQ · CQRV | 175/115 · 555 · 176/268 | Payment lot / returns lot |
| N01 | NACHA notification of change | proprietary | NOC file | **Never post**; master data within 6 banking days |
| F01–F05 | Fees, interest, charges | ACMT-MCOP/MDOP-FEES·INTR·CHRG | 698 · 398 · 354/359 · 654 | Posting rule, fee tolerance |
| T01/T02 | Book transfer / sweep | PMNT-RCDT/ICDT-BOOK · RCCN/ICCN-ICCT | 275/575 | Both legs |
| M01/M02 | Miscellaneous credit / debit | PMNT-RCDT/ICDT-ADJT | 399 · 699 | On account — never suspense |
| X01 | Unmapped code | anything not in the map | anything | **BLOCK + exception** |

Production codes used today (legacy validators, disbursement accounts) keep their own rule groups: 166, 168, 195, 255, 466, 468, 581 (and 166 on collection accounts; 143 on collection accounts like 166, 452 like 468). 275 / 575 (ZBA sweeps) are mapped without code-specific validation (business decision 2026-11-06) and carry disposition **NOT_POSTED**: they are never posted, and S10 accepts them unposted (audit A26). 166 disbursement follows the retrieval-log chain (business decision, audit A11): retrieval AP passes alone; AF needs the returns lot item; then DPAYH RETURNED. See `Legacy_Parity_Comparison.md`.

### A3. Triage playbook (RAG)

| Signal | Meaning | First action | Owner |
|---|---|---|---|
| **R14 UNMAPPED_BTC** (B) | The bank used a code nobody configured | Do not post manually. Identify the code on the bank's code sheet, add a ZCD_BTC_MAP row (category + rule group), re-run validation | Payment engine support + Treasury |
| **S01 OPENING_NE_PRIOR_CLOSING** | A statement is missing or was loaded twice | Check FEBKO for the account; request the missing statement from the bank | Treasury |
| **S02 BALANCE_ARITHMETIC** (B) | The file does not add up | Reject the file, ask the bank to resend | Treasury |
| **S06 control totals** (B, from parser) | File corrupted / truncated in transit | Do not import; request resend via PRISM | Payment engine support |
| **R07 / R07C / R07R / R07L** | Bank line cannot be tied to the payment engine record | Look up the reference in DPAYH / check register / returns lot / retrieval log; correct or open clarification | Disbursement ops |
| **R08 / R12** | Check amounts or totals differ from the register | Compare register and bank; possible reissue or bank error | Disbursement ops |
| **S10 ENTRIES_NOT_ACCOUNTED** (W) | Imported entries neither posted nor blocked | Work the FEBAN/FPB7 post-processing queue | Payment engine support |
| **CIRCUIT_BREAKER** | Run stopped: too many failures, or three packages in a row where a rule could not run | Look for a systemic cause (wrong file, configuration change, broken rule class) before re-running | Payment engine support |
| **PLUGIN_ERROR** + "entries not evaluated" in the run message | A rule raised; the lines of its group are **unevaluated** (counted as failed, never passed) | Fix the rule or its configuration; re-run | Payment engine support |
| **POSTING_INCOMPLETE** (S13, W) + "entries not evaluated (posting not complete)" in the run message | Entries expected to post are not posted: the statement import, FEBP or the clearing job had not finished, or lines were left unposted. Posting-dependent rules were not evaluated for them; run never green | Runbook §5c: check the predecessor jobs in Control-M / SM37, re-run `ZCD_EBS_VALIDATE` after they finished (idempotent); still open afterwards → FEBAN post-processing | Payment engine support |
| **NO_DATA** (run status N, RAG grey) | The run selected no statement — nothing was evaluated | Check the selection (company code, house bank, dates) and whether the bank delivered; maintain `EBS_EMPTY_FEED_OK` = X only for feeds that are intentionally empty | Payment engine support |
| **RULE_GROUP_EMPTY / RULE_UNUSABLE / KEY_LENGTH_CONFIG** (BLOCK) | Configuration gap: a mapped group without a usable rule, a rule without active definition, or a key length above the key width | Fix the configuration | Payment engine support |
| **TRAILER_FIELD_MISSING** (S06 B / S12) | A 49 / 98 / 99 trailer of the file has an empty total or count | Request a resend; a missing declaration is never replaced by the computed value | Treasury |
| **REF_TOO_LONG / REF_FORMAT** | The bank reference cannot be a document number (longer than the key, or not alphanumeric) | Look the entry up manually; it is never matched on a truncated key | Disbursement ops |
| **DUPLICATE_HISTORY** (R22) | The entry is already in an earlier statement of the account (look-back window) | Check FEBEP for the earlier statement before posting | Treasury |
| **AWAITING_LOT_TRANSFER** (W) | Payment / returns lot not found yet, statement inside the in-flight window (`EBS_INFLIGHT_HOURS`) | None while inside the window; a run after the window reports the original finding | Disbursement ops |
| **MISSING_TRAILER / FUNDS_LAYOUT** (B, BAI2) | A 49 / 98 / 99 record is missing, or a detail's funds-type block cannot be read | Request a resend | Treasury |
| **CAMT_DOCUMENT / INVALID_AMOUNT / INVALID_COUNT** (B, CAMT) | Namespace / version not approved, second message body, wrong statement element, or a value that is not a number | Request a corrected file; a new CAMT version is a parser change (§B6a) | Payment engine support |
| **ENTRY_NOT_BOOKED** (W, CAMT) | Entry with status PDNG / INFO (or none) — quarantined, not posted | Wait for the booked entry in a later statement | Treasury |
| **CAMT_BATCH_MISMATCH** (B) / **CAMT_DETAIL_AMOUNT_MISSING** (E) | Transaction details do not add up to their entry, or a detail has no amount | Post the entry manually from the bank advice; the detail lines are not emitted | Payment engine support |
| **MAP_CONFLICT** (B) | ZCD_BTC_MAP has a blank-flow row and a `*` row for the same code that contradict each other | Delete one row (the app stores `*`) | Payment engine support |

## Part B — Technical

### B1. Flow

```mermaid
flowchart LR
  subgraph IN[What comes in]
    F[Bank file BAI2 / CAMT.053 / CAMT.054]
    I[FEBKO / FEBEP after FF_5]
  end
  F -->|ZCL_CD_EBS_SRC_FILE + parser| P[Package: statements, lines, parser findings S00/S06/S11/S12]
  I -->|ZCL_CD_EBS_SRC_FEB, N statements per package| P
  P --> E0[0. Scope: FEB statements whose lines are not all payment engine accounts XBLNR → removed, counted out of scope]
  E0 --> E1[1. Resolver: account config, flow, ZCD_BTC_MAP → category / rule group; unmapped → R14 BLOCK]
  E1 --> E2[2. Statement rules S01–S12, R18]
  E2 --> E3[3. Line rules per rule group + '*' — blocked lines skipped]
  E3 --> ST[(ZCD_OPS_RUN / ZCD_OPS_FINDING)]
  ST -->|reconcile package scope, commit per package| CB{Circuit breaker}
  CB -->|end of run| AL[Alert router ZCD_OPS_ALRULE]
```

Before anything runs the engine takes the **run lock** for its variant (`ZCD_OPS_LOCK` via `E_TABLE`, kept across the package commits, released at the end); a second run of the same variant is refused with RUN_LOCKED. After saving each package's findings the engine **reconciles** the package's lines and statements: open exceptions of earlier runs for these objects that were not raised again are resolved; an exception raised again keeps owner, due date and first-seen time (`ZCL_CD_OPS_STORE`). A package with a PLUGIN_ERROR resolves nothing.

Points of no return: the commit after each package (findings durable) and the alert hand-over after the run. A failure between packages leaves the run in status R (running) — the morning report's health-of-health check flags runs that never closed.

### B2. Objects

| Layer | Object | Purpose |
|---|---|---|
| Types | `ZIF_CD_EBS_TYPES` | Format-neutral statement/line model and configuration types |
| Ports | `ZIF_CD_EBS_PARSER`, `ZIF_CD_EBS_SOURCE`, `ZIF_CD_EBS_RULE`, `ZIF_CD_EBS_CFG_DAO`, `ZIF_CD_EBS_FEB_DAO`, `ZIF_CD_EBS_SAP_DAO` | Strategy and repository interfaces |
| Domain | `ZCL_CD_EBS_BTC_RESOLVER`, `ZCL_CD_EBS_FINDING`, `ZCL_CD_EBS_PE_SCOPE` (payment engine account from XBLNR, statement scope), `ZCL_CD_EBS_R_*` (28 rules), `ZCL_CD_EBS_PARSER_BAI2/_CAMT` | No SQL |
| Repositories | `ZCL_CD_EBS_CFG_DAO`, `ZCL_CD_EBS_FEB_DAO`, `ZCL_CD_EBS_SAP_DAO` | All SQL |
| Application | `ZCL_CD_EBS_ENGINE`, `ZCL_CD_EBS_SRC_FEB`, `ZCL_CD_EBS_SRC_FILE`, `ZCL_CD_EBS_FACTORY`, `ZCL_CD_EBS_INJECTOR` | Orchestration |
| Presentation | `ZCD_EBS_VALIDATE` | Selection, ALV, background |

### B3. Customizing (EBS configuration app, delivery class C)

| Table | Key | Holds |
|---|---|---|
| ZCD_BTC_MAP | SCHEME, BTC_CODE, BANK_KEY, FLOW_TYPE | Category, rule group, expected direction, payment method, posting rule, action, **disposition** (blank = posted as usual, NOT_POSTED = never posted, A26) |
| ZCD_EBS_RULE_DEF | RULE_ID | Rule registry: level S/L, class, default severity/action, **NEEDS_POSTING** (rule reads posting evidence — not evaluated for a line expected to post but not posted, §A0), **FINDING_CLASS** (dashboard class of the rule's findings: DUPLICATE — seed S07, R09, R22; POSTING — seed S13; blank = neither; read by `ZI_CD_EbsFinding`) |
| ZCD_BTC_RULE | RULE_GROUP, RULE_ID | Rule assignment per group (`*` = all) with severity, action, PARAM1–3, tolerance, window. RULE_ID **NONE** marks a group that intentionally has no code-specific rule (A03) |
| ZCD_EBS_ACCT | BUKRS, HBKID, HKTID | **ACCOUNT_NO = 10-character payment engine account as derived from FEBEP-XBLNR** (§A0a; upper case, no leading blank — the active rows are the scope of validation and dashboard), bank key, format, default flow, currency, bank G/L, ACTIVE |
| ZCD_EBS_FLOW_PAT | PRIORITY, PATTERN | XBLNR pattern → flow (ported ZB_BAI_GL_CONFIG); PATTERN is PCRE, matched to the **complete value** (`matches( )` — never a partial `find`), **case ignored** (as the former CP wildcards), blank keeps its meaning at each place — see §B3a |
| ZCD_EBS_RSN_MAP | REASON | NACHA R01–R85 / NOC C01–C07 → payment engine return reason |
| ZCD_EBS_LOOKUP | LOOKUP_ID | Generic lookups of rule R21: table, key field, key kind (DOCNO / ZTNUM / REFERENCE), key length, status field, allowed values, check codes |

Lookup order in ZCD_BTC_MAP: bank + flow → bank + `*` → blank bank + flow → blank bank + `*`; ISO codes then fall back to the family row (`PMNT-ICDT`), then the proprietary code (BAI type codes in CAMT `Prtry` with issuer BAI reuse the BAI2 rows when `EBS_CAMT_BAI_FALLBACK` = X), then scheme PRTRY. Nothing found → X01.

### B3a. Flow patterns (PCRE, user decision 2026-11-06)

`ZCD_EBS_FLOW_PAT-PATTERN` is PCRE matched to the **complete XBLNR**, case ignored: `JPMC8XX1174412.*` captures every line of that account, `.*COLL.*` every XBLNR containing COLL; `COLL` alone captures only the XBLNR `COLL`. Active rows are tried by PRIORITY; the first match decides the flow, no match = the account default. A pattern that does not compile is refused by the EBS configuration app (message 418); if one is in the table anyway, a line that reaches it before a match is **blocked** with `FLOW_PATTERN_INVALID` (R14 family, severity B, message 547) — its flow is unknown, it is never guessed. The BAI issuer of CAMT proprietary codes is the constant `.*BAI.*`; the CAMT receiver path `MsgRcpt/Id/.*`. Check a pattern before saving it: `ZCD_OPS_PATTERN_CHECK`, area EBS_FLOW (FEBEP-XBLNR of the configured accounts in the window).

### B4. Rule catalog

| ID | Level | Class | Checks |
|---|---|---|---|
| S01 | S | ZCL_CD_EBS_R_S01_CONTINUITY | Opening = prior closing (tolerance) |
| S02 | S | ZCL_CD_EBS_R_S02_BALANCE | Opening + credits − debits = closing; declared totals |
| S03 | S | ZCL_CD_EBS_R_S03_SEQUENCE | Statement number gap / repeat |
| S04 | S | ZCL_CD_EBS_R_S04_ACCOUNT | Account configured, currency |
| S05 | S | ZCL_CD_EBS_R_S05_DATE | Date missing / future / stale |
| S06, S11, S12 (file) | parser | ZCL_CD_EBS_PARSER_* | Control totals, empty file, declared counts; an empty trailer total / count is TRAILER_FIELD_MISSING, never the computed value (A86) |
| S07 | S | ZCL_CD_EBS_R_S07_DUPLICATE | Duplicate in file / already imported |
| S08 | FMON | file registry | File expected and registered — file monitoring payment engine area |
| S09 | S | ZCL_CD_EBS_R_S09_COVERAGE | Unmapped entries per statement |
| S10 | S | ZCL_CD_EBS_R_S10_COMPLETE | Entries neither posted nor blocked |
| S12 (imported) | S | ZCL_CD_EBS_R_S12_COUNT | FEBKO-ANZES vs entries — also for the parser's S12 findings |
| S13 | S | ZCL_CD_EBS_R_S13_POSTED | Imported statements: entries expected to post (posting state O, not NOT_POSTED, not blocked) are posted — else one POSTING_INCOMPLETE per statement with count and total (§A0) |
| R01 | L | …_R01_SIGN | Direction vs map |
| R02 | L | …_R02_BOUNDS | Min/max (also R11 fee tolerance) |
| R03 | L | …_R03_CURRENCY | Currency |
| R04 | L | …_R04_REFERENCE | Reference present / alphanumeric |
| R05 | L | …_R05_REASON | Return / NOC reason: bank file — NACHA code mapped; FEB source — returns lot DFKKRP-RLGRD / NOC lot DFKKNRP-FLGRD filled, unambiguous, configured (NEEDS_POSTING) |
| R06, R16 | FMON | NOC lot reader | NOC 6-banking-day SLA, master data applied |
| R07 | L | …_R07_PAYMENT | DPAYH by DOC1R, status |
| R07C | L | …_R07C_CHECK | Check register, status |
| R07L | L | …_R07L_RETRIEVAL | ACH retrieval log status |
| R07R | L | …_R07R_RETURN_LOT | Returns lot item and status |
| R08 | L | …_R08_CHECK_AMOUNT | Amount vs original within tolerance |
| R09 | L | …_R09_DUPLICATE | Duplicate entry |
| R10 | L | …_R10_VALUE_DATE | Value date window (also R13) |
| R12 | L | …_R12_CODE_TOTAL | Settlement total = register total |
| R14 | built in | ZCL_CD_EBS_BTC_RESOLVER | Unmapped → BLOCK |
| R15 | L | …_R15_POSTING_RULE | Posting rule resolves / matches |
| R17 | FMON | ack adapters | Debit matches prior positive ack via PRISM |
| R18 | S | …_R18_GL_BALANCE | Bank G/L = closing |
| R19 | L | …_R19_FI_DOCUMENT | FI posting exists / cleared |
| R21 | L | …_R21_LOOKUP | Configurable lookup: PARAM1 = ZCD_EBS_LOOKUP ID; the line's key must exist in the configured table, with a status in the allowed values (any matching row). A name not in the DDIC or an unknown lookup raises → PLUGIN_ERROR, action BLOCK |
| R22 | L | …_R22_DUP_HISTORY | Entry already in another imported statement of the house bank account within WINDOW_DAYS (else `EBS_DUP_LOOKBACK_DAYS`): same reference, amount, sign and code (A14) |

**Keys (A65).** A bank reference becomes a document-number key only when it fits: the width comes from the key type (12 for OPBEL / AUGBL / DOC1R, VERIFY-DDIC), `EBS_KEYLEN_DOCNO` above it is KEY_LENGTH_CONFIG, a longer reference REF_TOO_LONG and characters outside 0–9 / A–Z REF_FORMAT. Nothing is truncated. Check numbers compare without leading zeros (`EBS_ZTNUM_IGNORE_ZEROS`) and within the company code and house bank account (A07).

**Configuration gaps (A03).** A finding carries the severity and action of its rule assignment (registry default when blank). A mapped rule group without usable rule, or an assignment whose definition is missing or inactive, is a configuration gap (action BLOCK).

**R05 — return / NOC reason (correction 2026-11-06).** FEBEP carries **no** return or NOC reason. *Bank file before import* (BAI2 / CAMT): the NACHA code delivered in the file (R01–R85, C01–C07) must be mapped in ZCD_EBS_RSN_MAP — unchanged (A28: placeholder = REASON_MAP_INCOMPLETE, NOC vs return = REASON_KIND, PARAM1 REQUIRED, format check without mapping). *Imported statement (FEB source)*: the reason is read from the lot the return / NOC processing created — returns: **DFKKRP-RLGRD** of the returns lot items with SELW1 = payment document (FEBEP-CHECT, methods E G H I J K L; the same read as R07R); NOC: **DFKKNRP-FLGRD** of the NOC lot items whose **INFOF** (CHAR 50) holds the payment document (AUGBL) or the payment reference — read with every form the reference can take (as delivered, without leading zeros, as 12-digit document key) and matched after condensing and removing leading zeros of all-digit values (`EBS_ZTNUM_IGNORE_ZEROS`); exact INFOF content VERIFY-SE11. The reason must be filled (else REASON_MISSING), one and the same for all items of the payment (else REASON_AMBIGUOUS, listing the reasons) and a configured payment engine reason of its kind — FICA_REASON of a ZCD_EBS_RSN_MAP return row for RLGRD, of a NOC row (C01–C07) for FLGRD, never a placeholder (else REASON_UNMAPPED). PARAM2 RETURN reads only the returns lot, NOC only the NOC lot, blank both. A payment without lot item is **not evaluated** by R05 (R07R / S13 own a missing lot — no second failure). R05 is seeded **NEEDS_POSTING**: the lots exist only after return / NOC processing, so an entry that is not posted yet is never judged.

**Posting-dependent rules (operating model 2026-11-06).** Seeded NEEDS_POSTING: R05, R07, R07L, R07R, R18, R19, R21, S10 (reasons in §A0). For an imported entry expected to post but not posted they are not evaluated; S13 reports the statement.

**In-flight grace (FS-CD review).** With `EBS_INFLIGHT_HOURS` > 0 a not-found of R07, R07L, R07R or R21 for a statement younger than the window is AWAITING_LOT_TRANSFER (W, NOTIFY, original message in DETAILS). Age from the statement's creation date/time, else from the start of the statement date.

### B5. Parameters (framework `ZCA_PARAM`, area `CD_EBS` — maintained in the app *Parameter areas* (`ZUI_CA_PARAM_O4`); definitions and delivered defaults: `config/param_definitions.csv`; flags are BOOL: a value row with blank value is off)

| Parameter | Default | Meaning |
|---|---|---|
| EBS_KEYLEN_DOCNO | 12 | Length of OPBEL/AUGBL/DOC1R keys built from the bank reference; above the key width (12) = KEY_LENGTH_CONFIG |
| EBS_KEYLEN_ZTNUM | 0 | 0 = check number as delivered (DFKKCR-ZTNUM = FEBEP-CHECT) |
| EBS_ZTNUM_IGNORE_ZEROS | X (BOOL) | Leading zeros of all-digit check numbers are not significant; a value row with blank value = off (zeros significant) |
| EBS_DFKKCR_BUKRS_FIELD | blank | DFKKCR field holding the company code (VERIFY-DDIC); blank = house bank only |
| EBS_DUP_LOOKBACK_DAYS | 5 | R22 look-back when the rule row has no WINDOW_DAYS |
| EBS_FEB_POSTED_FIELDS | VB1OK,VB2OK | FEBEP posting-area completion flags (comma list, at most 4; VB1OK / VB2OK confirmed 2026-11-07); an entry is posted when every flag is X; a name not in FEBEP stops the run (message 051); `NONE` = posting state not read (rules as before). If posting area 2 is not used and its flag stays blank on posted items, set `VB1OK` |
| EBS_EMPTY_FEED_OK | blank (BOOL) | X = a run without statements is an intentionally empty feed (green); blank = NO_DATA (grey) |
| EBS_INFLIGHT_HOURS | 0 | In-flight grace window in hours; 0 = off |
| EBS_RTRV_STATUS_FIELD | ZZ_RTRV_STATUS | Status field of ZCD_ACH_RTRV_LOG (validated against DDIC) |
| EBS_FEB_DEBIT_IND / EBS_FEB_CREDIT_IND | S / H | FEBKO/FEBEP debit/credit indicators |
| EBS_CAMT_BAI_FALLBACK | X (BOOL) | CAMT proprietary BAI codes reuse BAI2 map rows; a value row with blank value = off |
| EBS_GL_LEDGER | 0L | Ledger for R18 |
| EBS_CB_FAIL_PCT / EBS_CB_PACKAGES / EBS_CB_MIN_LINES | 50 / 3 / 20 | Circuit breaker |
| EBS_RESULT_MAX | 100000 | Findings / lines kept in memory for display (exact bound). Saving, counts, RAG and alerts always cover every finding (A67) |
| EBS_PARSER_BAI2 / EBS_PARSER_CAMT053 / EBS_PARSER_CAMT054 | parser classes (CLASS, interface ZIF_CD_EBS_PARSER, developer-owned) | Swap a parser by configuration (transport); a class without the interface is refused by ZCA_PARAM and the delivered parser is used |
| SLA_DAYS_EBS_B / _E / _W | blank (= SLA_DAYS_DEFAULT, 1) | Exception due date |

### B6. Extension guide (configuration only)

| Change | Rows to add | Code? |
|---|---|---|
| New bank transaction code (acceptance test 3) | ZCD_BTC_MAP row (scheme, code, bank or blank, flow, category, rule group); optional ZCD_BTC_RULE rows for a new rule group | No |
| New bank | ZCD_EBS_ACCT rows with BANK_KEY = the bank identifier as in the statement (user decision 2026-11-07); bank-specific ZCD_BTC_MAP rows (same BANK_KEY) only where the bank deviates; the FMON interface rows of the bank carry the same value | No |
| New validation rule parameterisation (acceptance test 4: closing deviates > 0.01) | ZCD_BTC_RULE row `*` / S01 with TOLERANCE 0.01, SEVERITY B, ACTION BLOCK | No |
| New return reason | ZCD_EBS_RSN_MAP row | No |
| New collection/disbursement account | ZCD_EBS_ACCT row (ACTIVE, ACCOUNT_NO = payment engine account from XBLNR, §A0a); ZCD_EBS_FLOW_PAT if XBLNR identifies the flow | No |
| New bank text in XBLNR (letters before the account) | Nothing — any leading letters are removed | No |
| Account part of XBLNR not 10 characters / bank text with digits | `GC_PE_ACCOUNT` in `ZIF_CD_EBS_TYPES` **and** the literals in `ZI_CD_EbsLineAcct` (+ tests) | Yes — both together |
| A check against a further table (exists / status) | ZCD_EBS_LOOKUP row + ZCD_BTC_RULE row with rule R21, PARAM1 = lookup ID | No |
| A genuinely new kind of check (logic no lookup can express) | New class implementing ZIF_CD_EBS_RULE (inherit ZCL_CD_EBS_RULE_BASE) + ZCD_EBS_RULE_DEF row + test class | Yes — one class |

### B6a. Playbook — add a new BAI / CAMT code and its validations

> **First principle:** a new code is configuration; code is the last resort.

All steps in the **EBS configuration app** (`ZUI_CD_EBS_CFG_O4`). New rows are created in DV1 and transported (design D-3).

1. **Is the code already handled?** The morning report / EBS run shows R14 `UNMAPPED_BTC` for it (blocked, never posted). Check the bank's code sheet with Treasury: meaning, debit or credit, collection or disbursement.
2. **Map the code** — one ZCD_BTC_MAP row: scheme, code, bank (blank = all banks), flow (D / C / `*`), category, expected direction, rule group.
   - Same behaviour as an existing code → reuse its rule group (examples, decision 2026-11-06: **143 → BAI166C on collection accounts only**; **452 → BAI468D**).
   - No code-specific checks → leave the rule group blank (= category, generic `*` rules only; example: **275 / 575 sweeps**).
3. **Validations with existing rules** — ZCD_BTC_RULE rows for the rule group: R01–R19 with PARAM1–3, tolerance and window (catalog B4).
4. **Validation against another table** — a ZCD_EBS_LOOKUP row (table, key field, key kind, status field, allowed values, check codes) and a ZCD_BTC_RULE row with **R21**, PARAM1 = lookup ID. Names are checked against the DDIC when saved and at run time.
5. **Only if nothing above can express the check** — a new rule class (one class, test-first, ZCD_EBS_RULE_DEF row).
6. Test in DV1 with a statement containing the code (test mode), transport, re-run in QA1, record in `Legacy_Parity_Comparison.md` if it replaces a legacy validator.

**Configuration only, or a parser change? (A97)** Configuration is enough when the parser already emits the entry as a monetary line: BAI2 detail codes 100–399 (credit) and 400–699 (debit) with a supported funds type (blank, 0, 1, 2, Z, V, S, D), and every booked CAMT entry (`Sts` BOOK) with an ISO or proprietary code. A **parser change** is needed when the bank profile differs in layout: BAI2 informational codes 700–999 (dropped as INFO_CODE_SKIPPED — a map row alone never posts them), a new funds-type layout or field position (else FUNDS_LAYOUT), a CAMT namespace / version outside camt.053 / camt.054 .001.02–08 (else CAMT_DOCUMENT), camt.052 reports, or an entry status other than BOOK that the business wants posted. Proof: `e2e_config_only_code_routed` (file text → parser → engine, configuration only) and `e2e_info_code_no_line`.

### B7. Run status
**Run status (A66, A68).** Statements out of the payment engine scope (§A0a) are counted in the run message, never a finding. A run that selected no statement ends with status **N** (NO_DATA) and RAG grey plus a NO_DATA finding, unless `EBS_EMPTY_FEED_OK` = X. Lines of a rule group whose rule raised (PLUGIN_ERROR) are unevaluated: counted as failed, reported in the run message and in the result; such a package counts for the circuit breaker. An inverted FEB date range is rejected. A server file that is not valid UTF-8, or that cannot be read to its end, is rejected (A69).

### B8. Not verified
Syntax and typing checked offline with abaplint (v758 rules, SAP stub library). Not activated in SAP; ABAP Unit not executed; DDIC fields marked `VERIFY-DDIC` in `ZCL_CD_EBS_FEB_DAO` and `ZCL_CD_EBS_SAP_DAO` must be confirmed in SE11 before activation. Confirmed 2026-11-07: FEBEP-VB1OK / VB2OK are the posted flags (parameter `EBS_FEB_POSTED_FIELDS`; on the first QA1 statement check that VB2OK is X on posted items without an area-2 posting, else set `VB1OK`). Also to confirm (phase 6): the 12-character width of OPBEL / AUGBL / DOC1R; the DFKKCR company-code field (`EBS_DFKKCR_BUKRS_FIELD`) and the FEBEP reason field (`EBS_FEB_REASON_FIELD`); READ DATASET return code 4 on an unterminated last line; the time zone of statement creation times (in-flight grace); **the XBLNR layout** (bank text + 10-character account + counter) on a production sample of each bank and that the payment engine accounts in `ZCD_EBS_ACCT-ACCOUNT_NO` are maintained in upper case; `REPLACE_REGEXPR` in the CDS view (`Dashboard_EBS_Validation.md` §9). Per-finding status: `history/Audit_History.md`.

## Overlap with the morning report check A_INFLIGHT (2026-11-07)

EBS validates each statement line at import (rule groups BAI166 / 168 / 195D / 466 / 468D: payment present, retrieval status, returns lot). The morning report check `A_INFLIGHT` evaluates the **whole lifecycle** of one payment reference across lines and days (roles per flow + class in `ZCD_HCK_BTCROLE`, sequences in `ZCD_HCK_SEQOUT`, `HCK_MORNING_REPORT.md` §7b-2) - e.g. 468 is a collection failure (redeposit pending) for collections and a retrieval failure for disbursement ACH, 195 a wire return on disbursement accounts and the Stripe payout deposit on the collection account. No EBS logic is duplicated: the scheme / code of a line comes from `ZCL_CD_EBS_SRC_FEB=>LINE_CODE` (also used by EBS), the returns lot from `ZIF_CD_EBS_SAP_DAO=>GET_RETURN_ITEMS` (now with the item amount DFKKRP-BETRW, VERIFY-DDIC), DPAYH status from `GET_PAYMENTS`; the dependency is one-way (HCK → EBS readers). `ZCD_BTC_MAP` (line categories and rule groups) and `ZCD_HCK_BTCROLE` (payment lifecycle) answer different questions and stay separate.

**Cheques (581 / 255 / corrections).** `A_INFLIGHT` evaluates the cheque lifecycle of a payment (DFKKCR-DOC1R = AUGBL → ZTNUM → last 13 characters = FEBEP-CHECT: clarification for several 581 / 255, manual clearing in FPCHR after a correction 399 / 699, 581 amount against the payment amount). A 581 or correction line whose cheque number matches **no** cheque in the register cannot be tied to a payment there; it is reported by EBS at import (rule group BAI581D: R08 against the register by ZTNUM; BAI255D: R07C) - no second implementation.


## Used by the morning report check A_RECON_3WAY (2026-11-07)

The three-way reconciliation (`HCK_MORNING_REPORT.md` §7d) scopes its bank leg by the payment engine account of FEBEP-XBLNR exactly as this area does: the account rows come from `ZIF_CD_EBS_CFG_DAO=>GET_ACCOUNTS` through `ZCL_CD_EBS_FACTORY` (`ZCD_EBS_ACCT`, active rows, ACCOUNT_NO upper case), the derivation is the same CDS expression as `ZI_CD_EbsLineAcct` in the HCK view `ZI_CD_HckRcBankLine` (literals compared with `ZIF_CD_EBS_TYPES=>GC_PE_ACCOUNT` by `cds_abap_parity`), and the EBS parameters `EBS_FEB_CREDIT_IND` / `EBS_FEB_DEBIT_IND` / `EBS_GL_LEDGER` are read through their EBS definitions. The dependency is one-way (HCK → EBS); nothing of EBS is changed. A change of the account layout or of these parameters is a change for both areas.

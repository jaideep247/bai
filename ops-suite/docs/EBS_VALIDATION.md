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

It **reports findings and never stops a posting**: by the time it runs every line is already posted (or deliberately left unposted). It changes no business data, starts no job and takes no lock on a standard table. The pre-posting path (`validate_for_posting`, BAdI `FIEB_CHANGE_BS_DATA`, enforce mode, per-line dispositions, blocked-line release app) stays in the code but is dormant and not part of this release (§B7, audit A02).

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

**Posting state of a line (FEB source).** The FEB source reads, per FEBEP item, the posting-area completion flags named in `EBS_FEB_POSTED_FIELDS` (default `VB1OK,VB2OK` — posting area 1 / 2 completed, **VERIFY-SE11**; each name is checked against the DDIC, an unknown name stops the run with message 051; `NONE` switches the read off). Every flag X = **posted** (P), otherwise **open** (O). The engine then marks a line **POSTING_OPEN** when it is open, its map row is not `NOT_POSTED` (sweeps 275 / 575 are never expected to post, A26) and it is not blocked (R14 lines are reported by R14).

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

For a POSTING_OPEN line these rules are **not evaluated** (a line rule does not receive the line; a statement rule does not receive the statement that holds it). The line is counted as **unevaluated** — never passed, never failed (a B / E finding of a rule that did run still counts it as blocked / failed) — and reported in the run message (message 542). Rule **S13** raises **one POSTING_INCOMPLETE per statement** with the number and total of those lines (seed W / NOTIFY). A run with such lines is **never green** (at least amber, whatever S13 is configured with), and the exception carry-forward leaves the open exceptions of those lines and their statement untouched — a check that did not run never resolves anything. Every rule that does not depend on the posting still runs on the line.

**Bank file source (BAI2 / CAMT before import).** The posting state is unknown by definition and is never invented: no line is POSTING_OPEN, S13 never reports, and the posting-dependent rules run exactly as before — R19 reports NOT_POSTED for a line without document unless PARAM3 = OPTIONAL, R18 compares the G/L balance as it is before the statement is posted, S10 skips file statements, R07* / R21 read the payment engine records as they are. Use the file source for structural checks before import; the posting-dependent results of the batch run come from the FEB source.

### A1. What it does
1. **Receives** a bank statement either as a file before import (BAI2 from JPMC/BOA, CAMT.053 statements, CAMT.054 notifications) or after FF_5/FEBP import (FEBKO/FEBEP).
2. **Checks the statement** as a whole (S-checks): balances chain from the previous statement, the statement adds up, numbers have no gaps, the account is known, nothing is a re-delivery, bank control totals agree.
3. **Classifies every line** by its bank transaction code (BAI2 type code or CAMT Domain-Family-Sub-family) into a business category (C01 ACH collection … X01 unmapped).
4. **Validates each line** with the rules configured for its category: right direction, right currency, reference present, matches the payment run / check register / returns lot / ACH retrieval, amounts agree, not a duplicate.
5. **Records** every problem as an owned exception with a due date, and **alerts** according to the alert rules.
6. **Would block** (pre-posting enforce mode — dormant, §B7) any line that must not post: unmapped codes, NOC entries, failed integrity checks. In this release the batch run after posting only reports (§A0).

### A2. Category reference (master prompt matrix)

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
| **PLUGIN_ERROR** + "entries not evaluated" in the run message | A rule raised; the lines of its group are **unevaluated** (counted as failed, never passed) and posting is blocked | Fix the rule or its configuration; re-run | Payment engine support |
| **POSTING_INCOMPLETE** (S13, W) + "entries not evaluated (posting not complete)" in the run message | Entries expected to post are not posted: the statement import, FEBP or the clearing job had not finished, or lines were left unposted. Posting-dependent rules were not evaluated for them; run never green | Runbook §5c: check the predecessor jobs in Control-M / SM37, re-run `ZCD_EBS_VALIDATE` after they finished (idempotent); still open afterwards → FEBAN post-processing | Payment engine support |
| **NO_DATA** (run status N, RAG grey) | The run selected no statement — nothing was evaluated | Check the selection (company code, house bank, dates) and whether the bank delivered; maintain `EBS_EMPTY_FEED_OK` = X only for feeds that are intentionally empty | Payment engine support |
| **RULE_GROUP_EMPTY / RULE_UNUSABLE / KEY_LENGTH_CONFIG** (BLOCK) | Configuration gap: a mapped group without a usable rule, a rule without active definition, or a key length above the key width | Fix the configuration (never released line by line) | Payment engine support |
| **TRAILER_FIELD_MISSING** (S06 B / S12) | A 49 / 98 / 99 trailer of the file has an empty total or count | Request a resend; a missing declaration is never replaced by the computed value | Treasury |
| **REF_TOO_LONG / REF_FORMAT** | The bank reference cannot be a document number (longer than the key, or not alphanumeric) | Look the entry up manually; it is never matched on a truncated key | Disbursement ops |
| **DUPLICATE_HISTORY** (R22) | The entry is already in an earlier statement of the account (look-back window) | Check FEBEP for the earlier statement before posting | Treasury |
| **AWAITING_LOT_TRANSFER** (W) | Payment / returns lot not found yet, statement inside the in-flight window (`EBS_INFLIGHT_HOURS`) | None while inside the window; the line is held as EXCEPTION, never auto-posted | Disbursement ops |
| **MISSING_TRAILER / FUNDS_LAYOUT** (B, BAI2) | A 49 / 98 / 99 record is missing, or a detail's funds-type block cannot be read | Request a resend; nothing of the file is posted | Treasury |
| **CAMT_DOCUMENT / INVALID_AMOUNT / INVALID_COUNT** (B, CAMT) | Namespace / version not approved, second message body, wrong statement element, or a value that is not a number | Request a corrected file; a new CAMT version is a parser change (§B6a) | Payment engine support |
| **ENTRY_NOT_BOOKED** (W, CAMT) | Entry with status PDNG / INFO (or none) — quarantined, not posted | Wait for the booked entry in a later statement | Treasury |
| **CAMT_BATCH_MISMATCH** (B) / **CAMT_DETAIL_AMOUNT_MISSING** (E) | Transaction details do not add up to their entry, or a detail has no amount | Post the entry manually from the bank advice; the detail lines are not emitted | Payment engine support |
| **MAP_CONFLICT** (B) | ZCD_BTC_MAP has a blank-flow row and a `*` row for the same code that contradict each other | Delete one row (the app stores `*`); never released | Payment engine support |
| **KILL_SWITCH_FALLBACK** (W) | TVARVC `ZCD_EBS_VALIDATION_MODE` missing, invalid or unreadable — MONITOR used | Maintain the switch (E / M / O) | Payment engine support |

### A4. Modes (kill switch)
TVARVC `ZCD_EBS_VALIDATION_MODE` (type P, NUMB 0000): **E** enforce (pre-posting hook blocks B findings), **M** monitor (record only — also the value used when the row is missing, holds another value or cannot be read; `read_mode` then returns a KILL_SWITCH_FALLBACK diagnostic, A91), **O** off. The scheduled report never reads the switch and never blocks; only the dormant pre-posting hook (§B7) would use the mode. Rollout value: **O**.

---

### Blocked-line release (operations app — dormant, not in this release)
Part of the pre-posting path (§B7); the app is not pulled by abapGit in this release. A blocked line can be released for posting only through the **Blocked line releases** app: one user requests (line, check code, reason, evidence), a second user approves. In enforce mode `validate_for_posting` then treats exactly that block as information; any other block on the line still blocks, and a rule that could not run (PLUGIN_ERROR / VALIDATION_ERROR) is never releasable. The approval resolves the exception (history action RELEASE). Details: `RAP_Ops_Apps.md` §2.2.

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
  P --> E1[1. Resolver: account config, flow, ZCD_BTC_MAP → category / rule group; unmapped → R14 BLOCK]
  E1 --> E2[2. Statement rules S01–S12, R18]
  E2 --> E3[3. Line rules per rule group + '*' — blocked lines skipped]
  E3 --> ST[(ZCD_OPS_RUN / ZCD_OPS_FINDING)]
  ST -->|reconcile package scope, commit per package| CB{Circuit breaker}
  CB -->|end of run| AL[Alert router ZCD_OPS_ALERT_RULE]
  E3 -.->|validate_for_posting, mode E/M/O| BADI[BAdI FIEB_CHANGE_BS_DATA]
```

Before anything runs the engine takes the **run lock** for its variant (`ZCD_OPS_LOCK` via `E_TABLE`, kept across the package commits, released at the end); a second run of the same variant is refused with RUN_LOCKED. After saving each package's findings the engine **reconciles** the package's lines and statements: open exceptions of earlier runs for these objects that were not raised again are resolved; an exception raised again keeps owner, due date and first-seen time (`ZCL_CD_OPS_STORE`). A package with a PLUGIN_ERROR resolves nothing.

Points of no return: the commit after each package (findings durable) and the alert hand-over after the run. A failure between packages leaves the run in status R (running) — the morning report's health-of-health check flags runs that never closed.

### B2. Objects

| Layer | Object | Purpose |
|---|---|---|
| Types | `ZIF_CD_EBS_TYPES` | Format-neutral statement/line model and configuration types |
| Ports | `ZIF_CD_EBS_PARSER`, `ZIF_CD_EBS_SOURCE`, `ZIF_CD_EBS_RULE`, `ZIF_CD_EBS_CFG_DAO`, `ZIF_CD_EBS_FEB_DAO`, `ZIF_CD_EBS_SAP_DAO` | Strategy and repository interfaces |
| Domain | `ZCL_CD_EBS_BTC_RESOLVER`, `ZCL_CD_EBS_FINDING`, `ZCL_CD_EBS_R_*` (28 rules), `ZCL_CD_EBS_PARSER_BAI2/_CAMT` | No SQL |
| Repositories | `ZCL_CD_EBS_CFG_DAO`, `ZCL_CD_EBS_FEB_DAO`, `ZCL_CD_EBS_SAP_DAO` | All SQL |
| Application | `ZCL_CD_EBS_ENGINE`, `ZCL_CD_EBS_SRC_FEB`, `ZCL_CD_EBS_SRC_FILE`, `ZCL_CD_EBS_FACTORY`, `ZCL_CD_EBS_INJECTOR` | Orchestration |
| Presentation | `ZCD_EBS_VALIDATE` | Selection, ALV, background |

### B3. Customizing (EBS configuration app, delivery class C)

| Table | Key | Holds |
|---|---|---|
| ZCD_BTC_MAP | SCHEME, BTC_CODE, BANK_KEY, FLOW_TYPE | Category, rule group, expected direction, payment method, posting rule, action, **disposition** (blank = posted as usual, NOT_POSTED = never posted, A26) |
| ZCD_EBS_RULE_DEF | RULE_ID | Rule registry: level S/L, class, default severity/action, **BLOCKS_POSTING** default (A27), **NEEDS_POSTING** (rule reads posting evidence — not evaluated for a line expected to post but not posted, §A0) |
| ZCD_BTC_RULE | RULE_GROUP, RULE_ID | Rule assignment per group (`*` = all) with severity, action, PARAM1–3, tolerance, window, **BLOCKS_POSTING** override (blank = registry default, Y, N). RULE_ID **NONE** marks a group that intentionally has no code-specific rule (A03) |
| ZCD_EBS_ACCT | BUKRS, HBKID, HKTID | Account number as the bank sends it, bank key, format, default flow, currency, bank G/L |
| ZCD_EBS_FLOW_PAT | PRIORITY, PATTERN | XBLNR pattern → flow (ported ZB_BAI_GL_CONFIG) |
| ZCD_EBS_RSN_MAP | REASON | NACHA R01–R85 / NOC C01–C07 → payment engine return reason |
| ZCD_EBS_LOOKUP | LOOKUP_ID | Generic lookups of rule R21: table, key field, key kind (DOCNO / ZTNUM / REFERENCE), key length, status field, allowed values, check codes |

Lookup order in ZCD_BTC_MAP: bank + flow → bank + `*` → blank bank + flow → blank bank + `*`; ISO codes then fall back to the family row (`PMNT-ICDT`), then the proprietary code (BAI type codes in CAMT `Prtry` with issuer BAI reuse the BAI2 rows when `EBS_CAMT_BAI_FALLBACK` = X), then scheme PRTRY. Nothing found → X01.

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
| S12 (imported) | S | ZCL_CD_EBS_R_S12_COUNT | FEBKO-ANZES vs entries. Blocks posting (seed ON) — also for the parser's S12 findings |
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

**Blocking flag (A27) and configuration gaps (A03).** A failed check of a rule whose blocks-posting flag is on carries action BLOCK (blocks in enforce mode, releasable per line); a rule with the flag off records its finding with the configured action. Seeded ON: S02, S04, S07, S12, R07, R07C, R07L, R07R, R08, R12, R19, R21. A mapped rule group without usable rule, or an assignment whose definition is missing or inactive, is a configuration gap (BLOCK, never released).

**R05 — return / NOC reason (correction 2026-11-06).** FEBEP carries **no** return or NOC reason. *Bank file before import* (BAI2 / CAMT): the NACHA code delivered in the file (R01–R85, C01–C07) must be mapped in ZCD_EBS_RSN_MAP — unchanged (A28: placeholder = REASON_MAP_INCOMPLETE, NOC vs return = REASON_KIND, PARAM1 REQUIRED, format check without mapping). *Imported statement (FEB source)*: the reason is read from the lot the return / NOC processing created — returns: **DFKKRP-RLGRD** of the returns lot items with SELW1 = payment document (FEBEP-CHECT, methods E G H I J K L; the same read as R07R); NOC: **DFKKNRP-FLGRD** of the NOC lot items whose **INFOF** (CHAR 50) holds the payment document (AUGBL) or the payment reference — read with every form the reference can take (as delivered, without leading zeros, as 12-digit document key) and matched after condensing and removing leading zeros of all-digit values (`EBS_ZTNUM_IGNORE_ZEROS`); exact INFOF content VERIFY-SE11. The reason must be filled (else REASON_MISSING), one and the same for all items of the payment (else REASON_AMBIGUOUS, listing the reasons) and a configured payment engine reason of its kind — FICA_REASON of a ZCD_EBS_RSN_MAP return row for RLGRD, of a NOC row (C01–C07) for FLGRD, never a placeholder (else REASON_UNMAPPED). PARAM2 RETURN reads only the returns lot, NOC only the NOC lot, blank both. A payment without lot item is **not evaluated** by R05 (R07R / S13 own a missing lot — no second failure). R05 is seeded **NEEDS_POSTING**: the lots exist only after return / NOC processing, so an entry that is not posted yet is never judged.

**Posting-dependent rules (operating model 2026-11-06).** Seeded NEEDS_POSTING: R05, R07, R07L, R07R, R18, R19, R21, S10 (reasons in §A0). For an imported entry expected to post but not posted they are not evaluated; S13 reports the statement.

**In-flight grace (FS-CD review).** With `EBS_INFLIGHT_HOURS` > 0 a not-found of R07, R07L, R07R or R21 for a statement younger than the window is AWAITING_LOT_TRANSFER (W, NOTIFY, original message in DETAILS). Age from the statement's creation date/time, else from the start of the statement date.

### B5. Parameters (ZCD_OPS_PARAM)

| Parameter | Default | Meaning |
|---|---|---|
| EBS_KEYLEN_DOCNO | 12 | Length of OPBEL/AUGBL/DOC1R keys built from the bank reference; above the key width (12) = KEY_LENGTH_CONFIG |
| EBS_KEYLEN_ZTNUM | 0 | 0 = check number as delivered (DFKKCR-ZTNUM = FEBEP-CHECT) |
| EBS_ZTNUM_IGNORE_ZEROS | X | Leading zeros of all-digit check numbers are not significant |
| EBS_DFKKCR_BUKRS_FIELD | blank | DFKKCR field holding the company code (VERIFY-DDIC); blank = house bank only |
| EBS_DUP_LOOKBACK_DAYS | 5 | R22 look-back when the rule row has no WINDOW_DAYS |
| EBS_FEB_POSTED_FIELDS | VB1OK,VB2OK | FEBEP posting-area completion flags (comma list, at most 4; VERIFY-SE11); an entry is posted when every flag is X; a name not in FEBEP stops the run (message 051); `NONE` = posting state not read (rules as before). If posting area 2 is not used and its flag stays blank on posted items, set `VB1OK` |
| EBS_EMPTY_FEED_OK | blank | X = a run without statements is an intentionally empty feed (green); blank = NO_DATA (grey) |
| EBS_INFLIGHT_HOURS | 0 | In-flight grace window in hours; 0 = off |
| EBS_RTRV_STATUS_FIELD | ZZ_RTRV_STATUS | Status field of ZCD_ACH_RTRV_LOG (validated against DDIC) |
| EBS_FEB_DEBIT_IND / EBS_FEB_CREDIT_IND | S / H | FEBKO/FEBEP debit/credit indicators |
| EBS_CAMT_BAI_FALLBACK | X | CAMT proprietary BAI codes reuse BAI2 map rows |
| EBS_GL_LEDGER | 0L | Ledger for R18 |
| EBS_CB_FAIL_PCT / EBS_CB_PACKAGES / EBS_CB_MIN_LINES | 50 / 3 / 20 | Circuit breaker |
| EBS_RESULT_MAX | 100000 | Findings / lines kept in memory for display (exact bound). Saving, counts, RAG and alerts always cover every finding (A67) |
| EBS_PARSER_BAI2 / EBS_PARSER_CAMT053 / EBS_PARSER_CAMT054 | parser classes | Swap a parser by configuration |
| SLA_DAYS_EBS_<severity> | 1 | Exception due date |

### B6. Extension guide (configuration only)

| Change | Rows to add | Code? |
|---|---|---|
| New bank transaction code (acceptance test 3) | ZCD_BTC_MAP row (scheme, code, bank or blank, flow, category, rule group); optional ZCD_BTC_RULE rows for a new rule group | No |
| New bank | ZCD_EBS_ACCT rows with BANK_KEY; bank-specific ZCD_BTC_MAP rows only where the bank deviates | No |
| New validation rule parameterisation (acceptance test 4: closing deviates > 0.01) | ZCD_BTC_RULE row `*` / S01 with TOLERANCE 0.01, SEVERITY B, ACTION BLOCK | No |
| New return reason | ZCD_EBS_RSN_MAP row | No |
| New collection/disbursement account | ZCD_EBS_ACCT row; ZCD_EBS_FLOW_PAT if XBLNR identifies the flow | No |
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

**Configuration only, or a parser change? (A97)** Configuration is enough when the parser already emits the entry as a monetary line: BAI2 detail codes 100–399 (credit) and 400–699 (debit) with a supported funds type (blank, 0, 1, 2, Z, V, S, D), and every booked CAMT entry (`Sts` BOOK) with an ISO or proprietary code. A **parser change** is needed when the bank profile differs in layout: BAI2 informational codes 700–999 (dropped as INFO_CODE_SKIPPED — a map row alone never posts them), a new funds-type layout or field position (else FUNDS_LAYOUT), a CAMT namespace / version outside camt.053 / camt.054 .001.02–08 (else CAMT_DOCUMENT), camt.052 reports, or an entry status other than BOOK that the business wants posted. Proof: `e2e_config_only_code_posts` (file text → parser → engine, configuration only) and `e2e_info_code_not_posted`.

### B7. Pre-posting hook (dormant — future enforcement phase, A02)
**Not part of this release.** The batch run validates after posting (§A0) and never reads the kill switch. The pre-posting path below stays in `ZCL_CD_EBS_ENGINE` unchanged and switched off: no BAdI implementation exists, TVARVC `ZCD_EBS_VALIDATION_MODE` = `O`, the blocked-line release app is not pulled by abapGit. It is described here only so a future phase can switch it on after its own review (A02).

Design (future): the engine exposes `validate_for_posting( iv_mode = zcl_cd_ebs_engine=>read_mode( ) is_package = … )`. A BAdI implementation of `FIEB_CHANGE_BS_DATA` would map the BAdI's statement structures to `ZIF_CD_EBS_TYPES=>TY_PACKAGE` and, when `block = abap_true`, prevent posting of the affected items. Lines handed over by such a caller carry no posting state, so the posting-dependent rules behave there as for the file source.

**Posting disposition (A85, dormant).** The decision also returns one disposition per line (`dispositions`, keyed by line key), which a BAdI would act on:

| Precedence | Disposition | Comes from |
|---|---|---|
| 1 | BLOCK | A finding with severity B or action BLOCK on the line, its statement or the package (the A27 flag sets action BLOCK; releases turn exactly their block into information) |
| 2 | NOT_POSTED | Map row disposition NOT_POSTED (sweeps 275 / 575) |
| 3 | EXCEPTION | A finding with action EXCEPTION, or blank action and severity E; map action EXCEPTION; AWAITING_LOT_TRANSFER; a line whose block was released but that has no usable mapping |
| 4 | ON_ACCOUNT | Map action ON_ACCOUNT, or a finding with action ON_ACCOUNT |
| 5 | AUTO_POST | Otherwise |

NOTIFY findings and warnings do not change the disposition. In mode M a BLOCK is returned as EXCEPTION (monitor never blocks); in mode O no disposition is returned.

**Run status (A66, A68).** A run that selected no statement ends with status **N** (NO_DATA) and RAG grey plus a NO_DATA finding, unless `EBS_EMPTY_FEED_OK` = X. Lines of a rule group whose rule raised (PLUGIN_ERROR) are unevaluated: counted as failed, reported in the run message and in the result; such a package counts for the circuit breaker. An inverted FEB date range is rejected. A server file that is not valid UTF-8, or that cannot be read to its end, is rejected (A69). **The BAdI method signature must be copied from SE18 before the implementation is written** (house rule: never guess a signature); it is therefore not part of this delivery.

### B8. Not verified
Syntax and typing checked offline with abaplint (v758 rules, SAP stub library). Not activated in SAP; ABAP Unit not executed; DDIC fields marked `VERIFY-DDIC` in `ZCL_CD_EBS_FEB_DAO` and `ZCL_CD_EBS_SAP_DAO` must be confirmed in SE11 before activation. Also to confirm (phase 6): **VERIFY-SE11 FEBEP-VB1OK / VB2OK** (posting area 1 / 2 completed — names, CHAR 1 with X when complete, and whether VB2OK is set for items without an area-2 posting; parameter `EBS_FEB_POSTED_FIELDS`); the 12-character width of OPBEL / AUGBL / DOC1R; the DFKKCR company-code field (`EBS_DFKKCR_BUKRS_FIELD`) and the FEBEP reason field (`EBS_FEB_REASON_FIELD`); READ DATASET return code 4 on an unterminated last line; the time zone of statement creation times (in-flight grace). Per-finding status: `Audit_Response_EBS.md`.

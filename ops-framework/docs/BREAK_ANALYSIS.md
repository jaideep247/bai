# Clearing-account break analysis

Release: 2026-11-11 (build F, gap 1). Component: operations framework `ZCA_OPS`. Product positioning: SAP-native
subledger operations and reconciliation evidence - **read-only, no matching engine, no postings, no clearing**.

> **First principle:** a clearing account keeps every posting of a payment until its counter-posting arrives; the
> lines of one reference (the assignment) must net to zero. A reference that does not is a *break* - and most breaks
> have an ordinary, nameable cause (the bank line arrives next month, the return is processed after the extract).
> Proving that cause, line by line and with the rule that named it, is what turns a list of differences into evidence.
>
> **Analogy:** a cloakroom. Every coat in has a ticket, every coat out returns it. At closing time the attendant does not
> re-sort the coats; she lists the tickets still out and, for each, why: "guest still inside", "collected after
> midnight", "ticket torn - unknown". Only the unknown ones need a manager.

## 1. What it does

| Step | Where | Rule |
|---|---|---|
| 1. Accounts | `ZCA_OPS_BRKACC` (configuration app `ZUI_CA_OPS_CFG`, entity *Break analysis clearing accounts*) | one row per clearing account (area, account ID, company code, G/L account, ledger; look-back / forward days and a group cap per account, else the `BRK_` parameters); the **business process** of the area it belongs to - an account whose process is not in effect (process catalogue) is not analysed |
| 2. Groups | `ZCL_CA_OPS_BRK_DAO=>OPEN_GROUPS` | the account's journal lines posted from key date - look-back to the key date, grouped **on the database** by assignment (ZUONR) and currency, `HAVING SUM <> 0`, oldest first, at most `BRK_MAX_GROUPS` - netting groups never leave HANA |
| 3. Lines | `=>GROUP_LINES` | package by package (`BRK_PACKAGE_SIZE` assignments, one IN list each): the lines of the break groups up to the key date and in the forward window (`BRK_FORWARD_DAYS`) - a line after the key date is context (it may clear the group), never an open line |
| 4. Linked objects | `ZCL_CA_OPS_BRK_LINKS` (link registry) | for the LINK conditions only: the rows of the linked objects (bank statement line, returns lot item, cheque, ...) of the package's open lines, one read per link and chunk (`LINK_READ_CHUNK`), at most `BRK_LINK_MAX_ROWS` rows per read, approved tables only, sensitive values masked |
| 5. Classification | `ZCL_CA_OPS_BRK_RULES` (pure) | each open line gets the bucket of the **first rule** (by sequence) whose conditions all hold - **first match wins**; no rule = `OTHER`; the group gets the bucket and rule of its **oldest open line**, with the reason "rule ID: reason" |
| 6. Snapshot | `ZCA_OPS_BRKRUN` / `_BRKGRP` / `_BRKITM` (report `ZCA_OPS_BRK_RUN`) | one snapshot per account and key date, saved and committed per account, with the **configuration version** (account, buckets, rules, conditions, `BRK_` values - `docs/EXPLAINABLE_RESULTS.md`); a cap reached = status P (partial), never silently complete |
| 7. Check | `ZCL_CA_OPS_CHK_BREAK` (registered check) | per account the latest snapshot: none / stale (`BRK_STALE_DAYS`) = warning `BREAK_NO_SNAPSHOT`; partial = warning `BREAK_PARTIAL` (check partial, nothing auto-resolved); every **OTHER** group at least `BRK_UNEXPLAINED_DAYS` old = exception `BREAK_UNEXPLAINED` with amount, currency, company code, business date (oldest line) and the snapshot's configuration version; at most `BRK_MAX_FINDINGS` per account, the rest summarised (294) |

Writes only its own snapshot tables - the journal, the subledger and the bank statements are only read.

## 2. Bucket model and rules (configuration)

**Buckets** (`ZCA_OPS_BRKBKT`, area-independent): ID, text, *explained* flag (counts toward the share explained of the
pilot pack), layer, sequence. `OTHER` = not explained, always.

**Rules** (`ZCA_OPS_BRKRUL`): area (`*` = every area - product rules), rule ID (prefix of its layer: `S4_`, `FICA_`, a
customer's own), sequence (unique per area), bucket, account pattern (PCRE on the account ID, blank = all), reason
(shown with the rule ID), active.

**Conditions** (`ZCA_OPS_BRKCND`, all of a rule must hold):

| Kind | Field | Operators | Value |
|---|---|---|---|
| `FIELD` (the line) | `POSTING_DATE`, `DOCUMENT_DATE`, `DOC_TYPE`, `DEBIT_CREDIT`, `ASSIGNMENT`, `REF_TYPE`, `RECON_KEY`, `AMOUNT`, `CURRENCY` | `EQ NE IN NI GE LE GT LT RX BL NB` | literal, comma list, or `@PARAMETER` |
| `GROUP` (its group) | `LINES`, `DEBITS`, `CREDITS`, `NET_AMOUNT`, `AGE_DAYS`, `CLEARS_LATER`, `LATER_DOC_TYPE`, `DAYS_TO_CLEAR` | same | same |
| `DAYS` (day window) | `PERIOD_END` (days from posting to the end of its month - calendar month, V138), `KEY_DATE` (days before the key date) | same (numbers) | same |
| `LINK` (linked object) | a field of the object the link reaches (blank = existence) | `EX` (a row with a listed value exists at least `MIN_COUNT` times), `NX` (none exists), or a comparison | link ID of the registry from `S4_JOURNAL_ITEM` |

`@PARAMETER` names a parameter of area `CA_OPS` (comma list or a single value); **a blank list never matches** (an
unset list explains nothing - reported as problem 288). Numbers compare as numbers. A rule with an unknown bucket,
field, operator or link is left out of the analysis with a configuration problem (284-289) - never applied half.

### 2a. Product defaults (`config/breaks`, delivered with the framework)

| Rule | Seq | Bucket | Conditions | Why |
|---|---|---|---|---|
| `S4_TIMING_EOM` | 100 | TIMING | line posted in the last `BRK_TIMING_DAYS` days of its month; the group is brought to zero by lines after the key date within `BRK_TIMING_DAYS` | last-days statements arriving next month |
| `S4_TIMING_RECENT` | 110 | TIMING | line posted at most `BRK_TIMING_DAYS` days before the key date | may still clear (daily runs) |
| `S4_RETRIEVAL` | 200 | RETRIEVAL_CUTOFF | cleared after the key date by a document type of `BRK_DOCTYPES_RETRIEVAL` | retrieval cut-off in the next period |
| `FICA_RETURN_LATER` | 300 | RETURN_NEXT_MONTH | cleared after the key date by a document type of `BRK_DOCTYPES_RETURN` | returns processed next month / after the extract |
| `FICA_RETRY` | 400 | RETRY_REDEPOSIT | three or more lines on one reference, two or more of them debits | presented again |

Buckets delivered: TIMING, RETRIEVAL_CUTOFF, RETURN_NEXT_MONTH, REDEPOSIT_NO_LOT, CHEQUE_EXCEPTION, RETRY_REDEPOSIT,
NEW_BTC, OTHER. The bank-code rules (redeposit without a returns lot, cheque exceptions, new bank transaction codes)
need a customer's link from the clearing line to the bank line and its code lists: they belong to the **customer
overlay** (the parameter names `BRK_BTC_NEW`, `BRK_BTC_REDEPOSIT`, `BRK_BTC_CHEQUE`, `BRK_BTC_CUMULATED` are product,
blank; the codes are the customer's). Offline check: `break_rules` of `tools/checks.py` (shared engine
`tools/abaptools/break_rules.py`; a consumer runs it over product + overlay).

## 3. Output

| Object | Use |
|---|---|
| `ZC_CA_OpsBrkGroup` (list report "Clearing account breaks", service `ZUI_CA_OPS_BRK`) | the breaks with the **bucket as a column**, amount per currency, age, cleared after the key date, rule and reason, reconciliation key, configuration version; object page with the lines |
| `ZC_CA_OpsBrkItem` | the lines: journal entry line (association to the released `I_JournalEntryItem`), dates, document type, amount, **reconciliation key** (reference key of the journal entry - the FI-CA reconciliation key of a G/L transfer), LATER flag, bucket, rule and the **evidence the rule read through the link registry** (linked object, its masked key, the value compared - e.g. the bank line and its transaction code). The walker (`ZIF_CA_OPS_LINK_WALKER`) drills further from the line's key (object `S4_JOURNAL_ITEM`) |
| `ZC_CA_OpsBrkBucket` | overview card **"Clearing account breaks by bucket"** (chart qualifier `ByBucket`): groups per bucket of the latest snapshots, the amount per bucket and currency in its table |
| `ZI_CA_OpsBrkCube` / `ZC_CA_OpsBrkQry` | analytical cube and query: account x bucket x currency (rows), amount, groups, lines, explained / unexplained, oldest age; latest snapshot by default. The currency is a dimension - **never summed across currencies** |
| `ZI_CA_OpsBrkSnap` | the snapshot shown per account and key date (last run of the key date, `IsLatest` for the latest key date) |

Read access: DCLs on the area and the company code (`ZCA_OPS` 03, `docs/auth_zca_ops.md` §3c). Report `ZCA_OPS_BRK_RUN`:
`ZCA_OPS` 16 for the area.

## 4. Integration

- **Process catalogue**: monitoring template `FICA_GL_BREAKS` (class `ZCL_CA_OPS_CHK_BREAK`, inactive) of the FI-CA
  process `FICA_GL_TRANSFER` (G/L transfer and reconciliation keys); a consumer onboards it as its business process
  (e.g. `CAT_PROCESS` = `FICA_GL_TRANSFER`). Activation honoured twice: the runner skips the check of a process not in
  effect, and the analysis skips the accounts of a process not in effect (290).
- **Link registry**: LINK conditions name links from `S4_JOURNAL_ITEM`; the field `VGEXT` (external transaction code)
  of `S4_BANK_STMT_LINE` is in the product layer (V138). A link switched off or invalid takes its rules out (287).
- **Explainable results**: every line and group names its rule; the snapshot and the check's findings carry the
  configuration version; a changed rule reopens a covered control sign-off (`CONFIG`).
- **Retention**: purge target `BREAK` (`ZCL_CA_OPS_BRK_PURGE`, registry row of the consumer, `RETENTION_DAYS_BREAK`); the
  latest snapshot of an account is never purged.

## 5. Parameters (area `CA_OPS`)

`BRK_LEDGER` (0L), `BRK_LOOKBACK_DAYS` (62), `BRK_FORWARD_DAYS` (10), `BRK_MAX_GROUPS` (20 000), `BRK_PACKAGE_SIZE`
(500), `BRK_MAX_ITEMS` (200 000), `BRK_LINK_MAX_ROWS` (5 000), `BRK_TIMING_DAYS` (3), `BRK_DOCTYPES_RETRIEVAL`,
`BRK_DOCTYPES_RETURN`, `BRK_BTC_NEW`, `BRK_BTC_REDEPOSIT`, `BRK_BTC_CHEQUE`, `BRK_BTC_CUMULATED` (blank),
`BRK_UNEXPLAINED_DAYS` (5), `BRK_STALE_DAYS` (2), `BRK_MAX_FINDINGS` (500), `BRK_KEY_DATE_LAG` (1),
`RETENTION_DAYS_BREAK` (400) - `docs/PARAMETERS.md`.

## 6. Performance design (2-million-payment days)

> The busiest clearing account holds millions of open lines; most of its references net to zero. The design never
> brings a netting reference to the application server and never reads a line one at a time.

| Read | Statement | Bound | Pre-check |
|---|---|---|---|
| Groups | ACDOCA `RLDNR` + `RBUKRS` + `RACCT` + `BUDAT` window, `GROUP BY ZUONR, RWCUR HAVING SUM( WSL ) <> 0 ORDER BY first date UP TO n ROWS` | only breaks return; `BRK_MAX_GROUPS`; window `BRK_LOOKBACK_DAYS` | **BRK-PV1**: plan keeps RLDNR / RBUKRS (primary key prefix) and RACCT / BUDAT as column predicates, aggregation on HANA, rows scanned vs returned recorded on the busiest account and the largest day |
| Lines | ACDOCA same predicates + `ZUONR IN` (package of ≤ `BRK_PACKAGE_SIZE` values) up to key date + forward days | `BRK_MAX_ITEMS` per account (partial beyond) | **BRK-PV2**: IN list of 500 assignments pushed down (no per-value statement), runtime per package |
| Linked rows | one dynamic read per link and chunk (`LINK_READ_CHUNK`) on an approved table, IN list of the to-field | `BRK_LINK_MAX_ROWS` per read (problem 293 beyond) | **BRK-PV3**: an index of the to-field (`FEBEP` by `CHECT`, `DFKKRP` by `SELW1`, `DFKKCR` by `DOC1R` - V118); a full scan fails the item and the link stays off |
| Snapshot | array inserts per account, commit per account | groups and lines of the caps | **BRK-PV4**: `ZI_CA_OpsBrkSnap` / `ZR_CA_OpsBrkBucket` read the snapshot header by index `ACC` (AREA, ACCT_ID, KEY_DATE) and the groups by `SNAP_ID` |

**Released views (D-C8 rule):** the group and line reads stay on ACDOCA - a `GROUP BY ... HAVING` with a row cap and an
assignment IN list on the busiest account are exactly the statements whose plan through `I_JournalEntryItem` is
unproven (the reasoning of LDG-PV7). They move to the released view only after BRK-PV1 / BRK-PV2 show the view keeps the
plan (same rows, runtime within 10 %); the drill-down to a line uses the released view by its key (V136). Memory:
groups × ~120 bytes + lines × ~250 bytes per account (200 000 lines ≈ 50 MB) - run one account per job step on the
busiest landscape (`P_ACCT`).

## 7. Running it

1. Configuration (DV1, customizing request): accounts, rules of the customer layer, `BRK_` values; approve the tables of
   the LINK conditions for the area (`ZCA_OPS_TABWL`).
2. Job `ZCA_OPS_BRK_RUN` (area, account blank = all, key date blank = today - `BRK_KEY_DATE_LAG`, test mode off) after
   the G/L transfer of the day; for the month-end view a run with the last day of the month as key date on the 2nd
   business day (the lines of the forward window explain the timing).
3. The registered check (`ZCA_OPS_CHECK_RUN` of the area) raises the unexplained breaks as exceptions.

VERIFY: V134-V138 (`docs/VERIFY.md`).

# FI-CA Cash Operations checks (ZCA_OPS, package ZCA_OPS_CASH)

> **First principle:** for every expected step of the cash cycle the product states what should have happened, reads
> the SAP standard tables to see whether it did, and says so in one of three ways - observed (with count, money,
> owner and the source keys), not expected (calendar), or unknown (the source could not be evaluated). Unknown is
> never green.
> **Analogy:** a parcel tracker for money: not "the van left the depot", but "these 3 parcels worth 250.00 EUR left
> without a delivery note, the depot reported 'done', the deadline is 10:00 today and this is who is on call".

Build N of Release 1 (`docs/release/RELEASE_1_PLAN.md`, review 2026-11-15 section 3 "FI-CA Cash Operations", P0
"FI-CA cash coverage and trace", finding 3 "expected, observed and unknown"). Product only: every check reads SAP
standard tables, the released view `I_JournalEntry` and the framework's own configuration - never a customer table.
Delivered **inactive** (catalogue monitoring rows); the status values of SAP tables are parameters with a pending
(blank) default, never guessed.

## 1. What is delivered

| Object | Role |
|---|---|
| `ZCL_CA_OPS_CHK_CASH_PAYRUN` | Payment run expected / completed, payments without document, proposal-to-payment gap |
| `ZCL_CA_OPS_CHK_CASH_PAYLOT` | Incoming payment lot not posted, lot items in clarification ageing |
| `ZCL_CA_OPS_CHK_CASH_RETURN` | Returns lot not closed, returns in clarification, reversal pending (no returns document) |
| `ZCL_CA_OPS_CHK_CASH_EBS` | Bank statement missing per account and working day, source stale, lines not posted, not in FI-CA |
| `ZCL_CA_OPS_CHK_CASH_CLEAR` | Clearing reset and payment reversal after the payment run paid out |
| `ZCL_CA_OPS_CHK_CASH_GLKEY` | Reconciliation key open past cutoff, transfer error, closed but not in the G/L |
| `ZCL_CA_OPS_CASH_EXC` | Exception builder: the typed exception and its ONE mapping into today's finding (section 6) |
| `ZCL_CA_OPS_CASH_CTX` | Run context of a check: parameters, business calendar window, owner, next cutoff, not evaluated, cap |
| `ZIF_CA_OPS_CASH_DAO` / `ZCL_CA_OPS_CASH_DAO` | Set-based reads (every count / sum / oldest date on the database), factory calendar seam |
| `ZI_CA_OpsCashJrnl` | G/L document header through the released view `I_JournalEntry` (no access control of its own, not exposed) |
| `ZCL_CA_OPS_CASH_FACTORY` / `_INJECTOR` | Data access resolution and its test double slot |
| `ZIF_CA_OPS_CASH_TYPES` | Stages, evaluation states, check codes, parameters `CASH_*`, messages 500-539, row types |
| `config/cash/fixtures.json` | Offline fixture spec: 30 scenarios, the same as the ABAP Unit tests (section 7) |

Licensing: module **`CASH_OPS`** (requires `CATALOGUE_FICA`; `config/licensing/modules.json`, module map regenerated).
The runner's licence gate covers the six check classes through the module map.

## 2. Registration (catalogue and check registry)

Each check is a monitor of its catalogue process in `config/catalogue/packages/fica.json` (`class` = the check class)
and therefore a row of the check registry (`config/catalogue/monitoring/zca_ops_check.csv`, area `CA_FICA`,
company-code aware, schedule group `DAILY`, **inactive**) and of the control coverage (`zca_ops_ctlchk.csv`: the
process control covers `GROUP2` = the check ID - this is where the owner comes from).

| Check ID | Catalogue process | Class |
|---|---|---|
| `FICA_CASH_PAYRUN` | `FICA_PAYRUN` | `ZCL_CA_OPS_CHK_CASH_PAYRUN` |
| `FICA_CASH_PAYLOT` | `FICA_PAY_LOTS` | `ZCL_CA_OPS_CHK_CASH_PAYLOT` |
| `FICA_CASH_RETURNS` | `FICA_RETURNS` | `ZCL_CA_OPS_CHK_CASH_RETURN` |
| `FICA_CASH_EBS` | `FICA_EBS_LOTS` | `ZCL_CA_OPS_CHK_CASH_EBS` |
| `FICA_CASH_CLEARING` | `FICA_CLEARING` | `ZCL_CA_OPS_CHK_CASH_CLEAR` |
| `FICA_CASH_GLKEY` | `FICA_GL_TRANSFER` | `ZCL_CA_OPS_CHK_CASH_GLKEY` |

The older no-code aggregate templates of the same processes (`FICA_PAYRUN_NOPAY`, `FICA_LOT_OPEN`, `FICA_LOT_CLARIF`,
`FICA_RET_OPEN`, `FICA_EBS_NOLOT`, `FICA_CLR_RESET`, `FICA_GL_OPENKEY`) stay delivered and inactive; activate either
the template or the check, never both for the same rule (decision D-N1).

## 3. Expected, observed, unknown

| Situation | Result | Severity | Check is |
|---|---|---|---|
| Output present and complete | nothing (observed) | - | complete (earlier exceptions auto-resolve) |
| Output present, incomplete / late | exception per object, company code, currency | E | complete |
| Expected day without output and without any job evidence | `PAYRUN_MISSING` (evaluation `STALE`), `EBS_SOURCE_STALE` | E | complete |
| Job finished, no output | `CASH_ZERO_VOLUME` - a valid zero-volume day | I | complete |
| Non-working day of the business calendar | `CASH_NOT_EXPECTED` | I | complete |
| Status value pending, calendar missing, read failed, accounts unknown | `CASH_NOT_EVALUATED` (stage, source, parameter, error trace) | W | **partial** |
| More objects than `CASH_MAX_ROWS` | first ones reported + `CASH_RESULT_CAPPED` | W | **partial** |
| Reset / reversal in the window | exception | E | always **partial** (an operator closes it) |

"Partial" is the runner's existing rule: the earlier exceptions of the check stay open (no auto-resolve), so a failed
read never makes yesterday's exception disappear.

## 4. The controls

Days: `today` = the run's date; window = `today - CASH_LOOKBACK_DAYS` to `today - lag`. Status VALUES (lot status,
returns lot status, reference type, house banks, payment-order methods) are parameters with blank default: blank = the rule reports "not
evaluated (value pending)". Indicator fields (X / blank) are compared as set / not set; their meaning is VERIFY.

### 4.1 Payment run (`FICA_CASH_PAYRUN`)

- **Should have happened:** on each working day of `CASH_CALENDAR` (lag `CASH_PAYRUN_LAG_DAYS`) a payment run paid the
  company codes of `CASH_PAYRUN_BUKRS` (blank = any); every payment of a run at least `CASH_PAYRUN_MIN_AGE_DAYS` old has
  its payment document; a proposal is paid in full.
- **Detected:** `DPAYH` grouped by `LAUFD`, `LAUFI`, `XVORL`, `BBUKR`, `WAERS`, `RZAWE` (count, `SUM(RWBTR)`, count /
  sum where `DOC1R` is initial; proposal rows `XVORL` set never count as payments without document; the payment
  methods of one run, company code and currency are summed, the payments without document of a payment-order method
  of `CASH_PAYRUN_ORDER_METHODS` left out - such a method posts its document only after the bank confirmed the order)
  and the run's jobs (`TBTCO`, name `CASH_PAYRUN_JOBNAME`, `*` = any characters, `_` literal).
  No payment and no finished job = `PAYRUN_MISSING`; cancelled job = `PAYRUN_JOB_FAILED`; finished job without
  payment = `CASH_ZERO_VOLUME`; payments without document = `PAYRUN_NO_DOCUMENT`; proposal minus payment run of the
  same run date / ID = `PAYRUN_PROPOSAL_GAP` (only with `CASH_PAYRUN_GAP_ACTIVE` = X, after V221).
- **Failure injection:** when the job of the run date **finished successfully** and the output is incomplete, the
  exception carries stage **`JOB_OK`** and message 504 ("Job ... finished, run ... incomplete").
- **Expected run:** matched on the run date (`LAUFD` = the day of the scheduler job) and company code, never on a
  fixed `LAUFI` - the mass activity scheduler (`RFKK_MA_SCHEDULER`) takes `LAUFI` from the template's ID, or its first
  3 characters plus a counter when that key already ran that day (seen on the reference system).
- **Not in a run (not evaluated by this check):** an item without payment method on the item (`DFKKOP-PYMET`) and an
  item due after the run's issue date are not paid by design (seen in the test tool); they belong to an item-level
  "not in run" classification, not to the run check.
- **Evidence:** `LAUFD/LAUFI`, `JOBNAME/JOBCOUNT` (plus the job line: status, end).
- **Pending:** V221 (`XVORL` proposal semantics, same run ID of proposal and run, `RWBTR` sign), V220 (job naming).

### 4.2 Incoming payment lot (`FICA_CASH_PAYLOT`)

- **Should have happened:** a lot is posted / closed within `CASH_LOT_DAYS`; no item waits in clarification longer than
  `CASH_LOT_CLARIF_DAYS`.
- **Detected:** `DFKKZK` (status `STAZS` none of `CASH_LOT_DONE_STATUS`, created `ERDAT`) joined to `DFKKZP` (`BUKRS`,
  `WAERS`, `SUM(BETRZ)`) per lot; `DFKKZP-XKLAE` set, oldest `BUDAT` per lot.
- **Evidence:** `KEYZ1`. **Pending:** `CASH_LOT_DONE_STATUS` values (V222), `XKLAE` meaning (V223).

### 4.3 Returns lot (`FICA_CASH_RETURNS`)

- **Should have happened:** a returns lot is closed within `CASH_RET_DAYS`; no return waits in clarification longer
  than `CASH_RET_CLARIF_DAYS`; every return has its returns document (the reversal of the returned payment) within
  `CASH_RET_DAYS`.
- **Detected:** `DFKKRK` (`STARS` none of `CASH_RET_DONE_STATUS`) joined to `DFKKRP` (`SUM(BETRR)`); `DFKKRP-XKLAE` set;
  `DFKKRP-RLBEL` initial.
- **Evidence:** `KEYR1`. **Pending:** `CASH_RET_DONE_STATUS` (V224), `XKLAE` / `RLBEL` meaning (V225).
- **Not covered:** "returns without lot" (a return the bank reported that never reached a returns lot) - it needs the
  bank transaction codes of returns and belongs to the statement-to-lot link (decision D-N4).

### 4.4 Bank statement (`FICA_CASH_EBS`)

- **Should have happened:** every account (`BUKRS` / `HBKID` / `HKTID`) that delivered a statement in the last
  `CASH_EBS_ACCOUNT_DAYS` has one for each working day (lag `CASH_EBS_LAG_DAYS`); every line is posted within
  `CASH_EBS_POST_DAYS` of the import; statements of the house banks `CASH_EBS_FICA_BANKS` reach FI-CA as payment lots.
- **Detected:** `FEBKO` per account and `AZDAT`; no statement of any known account for a day = **one**
  `EBS_SOURCE_STALE` (not one per account), else `EBS_STATEMENT_MISSING` per account; `FEBEP-VB1OK` not set per
  statement and currency (`SUM(KWBTR)`); lines of a statement without a `DFKKZK` naming its `KUKEY`.
- **Evidence:** `KUKEY`, `HBKID/HKTID` (a label, never an account number). **Pending:** V226 (`AZDAT` / `EDATE` /
  `VB1OK`), V227 (`DFKKZK-KUKEY`, the house banks list).

### 4.5 Clearing reset / reversal after payout (`FICA_CASH_CLEARING`)

- **Should have happened:** once a payment run paid an item, its clearing stays and the payment document stays
  unreversed.
- **Detected (last `CASH_CLR_DAYS`):** `DFKKRAPT` resets (`STDAT`, clearing reason in `CASH_CLR_AUGRD`, blank = any)
  whose clearing document `AUGBL` is a `DPAYH-DOC1R` of a payment run (not a proposal); `DPAYH` payment documents whose
  `DFKKKO-STORB` names a reversal document entered (`CPUDT`) in the window. Direction (seen on the reference system):
  `STORB` on the original points to the reversal, `STBEL` on the reversal names the original, and the original's items
  get clearing reason 05 with `AUGBL` = the reversal - `STBEL` on the original is never read.
- **Evidence:** `AUGBL` / `DOC1R`, `OPBEL`, `LAUFD/LAUFI`. Always partial. **Pending:** V228.

### 4.6 Reconciliation key to the G/L (`FICA_CASH_GLKEY`)

- **Should have happened:** a key is closed within `CASH_GLKEY_OPEN_DAYS`, transferred without error, and
  `CASH_GLKEY_GL_DAYS` after closing each company code of its totals has an unreversed G/L document with reference
  type `CASH_GL_AWTYP` and the key as reference.
- **Detected:** `DFKKSUMC` (`XCLOS`, `CPUDT`, `CLDAT`, `XERRO`) joined to `DFKKSUM` (per `BUKRS`, `WAERS`; the debit side
  `SHKZG` not H, `SUM(ABS(BETRW))`, line count); the G/L through `ZI_CA_OpsCashJrnl` (`ReferenceDocumentType`,
  `OriginalReferenceDocument` = FIKEY, `CompanyCode`, `ReverseDocument` initial) in a `NOT EXISTS`. `AWKEY` = FIKEY
  (left-aligned, no suffix) is confirmed by the user; the reference type is not (`CASH_GL_AWTYP`, FKKSU expected).
- **Evidence:** `FIKEY`, `AWTYP/AWKEY` of the journal entry that should exist. **Pending:** `CASH_GL_AWTYP` (V229).

## 5. Exception content (every finding)

| Content | Where it is today |
|---|---|
| Count | `MESSAGE` (message variable), `DETAILS` line 531, alert `ITEM_COUNT` |
| Amount and currency (one currency per finding, never summed across currencies) | `AMOUNT` / `CURRENCY` |
| Oldest item / age | `BUS_DATE` (age = run date - business date), `DETAILS` line 532 |
| Next cutoff | `DETAILS` / context line 533 (or 539 "unknown"): next working day of `CASH_CALENDAR` at the control's `CUTOFF_TIME`, time zone `CONTROL_TIME_ZONE` (the control review's) |
| Owner | `DETAILS` / context line 534 (or 538): the active control covering the check (owner, backup, team), else the process owner; the worklist's team column reads the same control (`ZI_CA_OpsFindTeam`) |
| Stage | `RULE_ID` (SCHEDULE, JOB, JOB_OK, PROPOSAL, PAYMENT, POSTING, CLARIFY, RETURNS, REVERSAL, ARRIVAL, TRANSFER, RESET, CLOSE, GL) |
| Evaluation | `DETAILS` line 530 (OBSERVED, ZERO_VOLUME, NOT_EXPECTED, STALE, NOT_EVALUATED) |
| Evidence keys at source grain | `OBJECT_KEY` (source key / company code / currency) and `DETAILS` lines 535 |
| Rule parameter | `CFG_RULE` |
| Source tables | `REFERENCE` |

## 6. The exception builder and build K's contract

The checks never fill a finding. They fill `ZIF_CA_OPS_CASH_TYPES=>TY_EXCEPTION`; `ZCL_CA_OPS_CASH_CTX=>FINDING`
completes owner, cutoff and age and calls **`ZCL_CA_OPS_CASH_EXC=>TO_FINDING`** - the only place that knows the
finding's fields. No column was added to `ZCA_OPS_FINDING` and no store was created.

Build K's shared exception contract (`docs/EXCEPTION_CONTRACT.md`) was adopted with the merge of 2026-11-16 as
that one mapping change: `TO_FINDING` also fills `UNKNOWN_COUNT` (1 for an absence; all items when they carry no
amount), `DEADLINE_AT` / `CALENDAR_ID` (the cutoff), `STAGE`, `RESP_USER` / `RESP_TEAM` / `RESP_SOURCE` (control `C`,
process owner `P`, none `N`); `FINDING` sets `EVID_KEY` and collects one typed evidence row per evidence key
(`ZCL_CA_OPS_CASH_EXC=>EVIDENCE_ROWS`), which each check returns in `TY_RESULT-EVIDENCE` for the runner to store
(`ZCA_OPS_FNDEVI`). The detail lines of section 5 stay. The six checks changed by one line each (return the evidence);
`MISSING( )` is empty for every finding (EXCEPTION_CONTRACT.md section 3 has the field mapping).

## 7. Fixtures, failure injection and the agreement of worklist, dashboard and export

- **ABAP Unit:** OSQL doubles of every table and the CDS view (`ZCL_CA_OPS_CASH_DAO`), pure tests of the builder and
  the context, and one test include per check on the data access double. Each scenario of `config/cash/fixtures.json`
  names its test method; the comment above the test names the scenario ID.
- **Failure injection:** `PAYRUN-04` - job finished successfully (`TBTCO` status F), one payment of three without
  payment document: exception `PAYRUN_NO_DOCUMENT` stage `JOB_OK`, `20261112/PAY01/ZT01/EUR`, 250.00 EUR, 1 item,
  oldest 2026-11-12, age 4, owner. Read failures (`PAYRUN-07`, `PAYLOT-05`, `RETURN-04`, `CLEAR-03`, `GLKEY-04`) are
  "not evaluated", partial.
- **Root test** `tools/tests/test_cash_fixtures.py` validates the spec format, the check codes, stages, evaluations
  and parameters against the types interface, the ages against the dates, the test methods and the catalogue
  registration. The same scenarios run on a system later (V235): the `given` rows are SAP table rows.
- **One stored value, three readers:** the worklist (exceptions app `ZC_CA_OpsException`: Amount, Currency, Business
  date, Message, Owner, Team - Currency and Business date are now list columns), its spreadsheet export (the list
  report's export of the same projection) and the dashboard card (`ZR_CA_OpsCheckStatus`: open exceptions per check
  and company-code slice) read the same `ZCA_OPS_FINDING` rows. Amounts are never summed across currencies: each
  finding has one currency and the card counts exceptions, not money.

## 7a. Evaluation state (2026-11-16, build O)

`ZCL_CA_OPS_CASH_CTX=>FINDING` folds the evaluation of every exception (`OBSERVED` with an exception = findings,
`ZERO_VOLUME` = `ZERO_OK`, `NOT_EXPECTED` = `HOLIDAY`, `STALE`, `NOT_EVALUATED` = not evaluated) into the check's
`TY_RESULT-EVAL` (`EVAL( )`, returned by each of the six checks); the runner stores the framework's evaluation record
(`docs/EVALUATION_AND_COVERAGE.md` section 1.1). The detail line 530 stays.

## 8. Configuration (parameters, area CA_OPS)

See `docs/PARAMETERS.md` (prefix `CASH_`). Minimum to evaluate: `CASH_CALENDAR`, the process controls with owner,
team and `CUTOFF_TIME`, `CASH_PAYRUN_JOBNAME`; the pending values `CASH_LOT_DONE_STATUS`, `CASH_RET_DONE_STATUS`,
`CASH_EBS_FICA_BANKS`, `CASH_GL_AWTYP` after their VERIFY items.

## 9. Pending (VERIFY V220-V237, `docs/VERIFY.md`) and limits

- Status values and indicator meanings of every table (V220-V229); the factory calendar FM (V230); offline-unproven
  ABAP SQL constructs (V231); volume and plans (V232, PlanViz CASH-PV1 .. CASH-PV6); ABAP Unit on a system (V233); the
  owner / cutoff configuration (V234); fixture replay (V235); worklist / export columns (V236); licence gate (V237).
- Expected days are per area (and per company code list for the payment run), not per run variant or per account
  calendar (D-N2). The account expectation is data-driven (accounts that delivered recently) (D-N3).
- The checks only read; nothing is posted, reversed, restarted or released.

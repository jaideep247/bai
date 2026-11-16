# Payment file lifecycle (module CASHOPS)

> **First principle:** a payment is only safe when every hand-off of its file - generated in SAP, picked up,
> delivered, received by the bank, accepted by the bank, settled - is proven by a record, on time; a hand-off
> nobody can prove is the place where the process stopped.
> **Analogy:** parcel tracking - every scan (packed, handed to the courier, delivered, signed for) is a record with a
> time; a parcel whose "signed for" scan is missing after the promised time is a case, and the case says where the
> parcel last was, what was in it, who must answer and which scans prove it.

Release 2026-11-15 (build K), first module of the FI-CA cash operations release. Status: built and lint-clean
(abaplint, 7.58 syntax), offline fixtures green in two integration setups; **not activated, ABAP Unit not executed**
(`docs/VERIFY.md` V170-V181).

## 1. What a support user sees - the flagship case

A disbursement file of today's payment run: the SAP job finished at 16:20, the transfer delivered the file to the
bank at 16:45, the bank confirmed receipt at 17:00 - and at 11:00 the next business day there is still no
acceptance, although the site promised "accepted by 10:00 of the next business day".

| The support user's question | Where it is answered |
|---|---|
| Which payments and amounts are affected? | Worklist `ZUI_CA_OPS_PAYFILE`, one row per file **and currency**: 3 payments, USD 3,500.50 and 1 payment, EUR 200.00 - never one sum across currencies; payments with an unknown amount counted apart; facet *Affected payments* (paged, payee masked, payment document, bank answer per payment) |
| Where did the process stop? | Column *Stage reached* = `RECEIPT`, *Stopped before* = `ACCEPTED`, *Deadline* 10:00 (business calendar of the file type), *Overdue* 60 minutes; facet *Stage timeline* - every configured milestone with its status (reached, late, implied, pending, missing, rejected, partial, failed, unknown), deadline and observation time. Receipt and acceptance are always two rows |
| Who owns the response? | *Responsible user / team* of the open exception (from the control register: the control that covers the check, else the owner of the file type's business process - `ZIF_CA_OPS_OWNER`), *Assigned to* once someone took it; navigation to the exceptions app |
| Which records support the finding? | Facet *Evidence* - one row per record at source grain: the SAP payment run (run date / ID, link object `FICA_PAYMENT_RUN`), the SAP job (name and count, `S4_BACKGROUND_JOB`), the payment documents, the transfer record of the middleware or the folder log, the bank's receipt with its own reference and version - each with system, logical system / client, occurrence and observation time, match quality and the key values a link walk starts from |

The check `ZCL_CA_OPS_CHK_PAYFILE` raises `PF_ACK_MISSING` (severity E: past the grace minutes; B from
`PF_BREACH_RED_MIN` minutes or the amount limit of the currency and company code) - one exception per file and
currency, each carrying the exception contract (section 6). Its message: *File F1: bank acceptance missing since
2026-11-17 10:00:00 UTC (2 payments, USD 3,500.50)*.

## 2. Lifecycle model

Milestones, in this order (`ZIF_CA_OPS_PF_TYPES=>GC_MILESTONE`, product vocabulary):

| Milestone | Meaning | Typically evidenced by |
|---|---|---|
| `PAYRUN` | The FI-CA payment run produced the payments of the file | file source (SAP: `DPAYH`) |
| `GENERATED` | The payment medium / file was generated in SAP | scheduler source (SAP job; a site's own scheduler) |
| `PICKUP` | A middleware picked the file up | transfer source (middleware) |
| `DELIVERED` | The file was delivered onward toward the bank (middleware hop or direct upload) | transfer source |
| `RECEIPT` | The bank has the file (transport-level acknowledgement) | acknowledgement source |
| `ACCEPTED` | The bank accepted the payments (accepted / rejected / partly accepted) | acknowledgement source (per file, batch or payment) |
| `SETTLED` | Posting / settlement evidence (bank statement) | statement source (optional) |

Rules (`ZCL_CA_OPS_PF_LIFECYCLE`, mirrored by `tools/abaptools/payfile.py`):

1. **Statuses.** A milestone with evidence is `REACHED` (or `LATE` when observed after its deadline), `REJECTED`,
   `PARTIAL` or `FAILED`; without evidence it is `IMPLIED` when a later milestone has evidence (the bank cannot accept
   a file it never received), `UNKNOWN` when its deadline passed and its source failed or is stale, `MISSING` when its
   deadline passed, else `PENDING`. A file type without acknowledgement (`ACK_LEVEL` N) has no `RECEIPT` / `ACCEPTED`.
2. **Order-independent.** The latest answer decides (a retried transfer succeeds after its failure); on a tie the worse
   one. The milestone counts as reached at the first time the decisive answer was given - a repeated acknowledgement is
   never "later". Accepted and rejected for the same scope is a **conflict** (`PF_ACK_CONFLICT`).
3. **Granularity.** `ACK_LEVEL` F (file), B (batch: every batch of the file's payments must be answered), P (payment:
   every payment); a file-level answer of a scoped type answers every scope; an answer outstanding is `PENDING` before
   the deadline and `PARTIAL` after it. One acknowledgement may name several files (`ACK_MULTI`, the event's
   `COVERS`): it is stored once per file.
4. **Where it stopped.** *Stage reached* = the last milestone reached in order; *next* = the first required milestone
   not reached; its deadline and the minutes overdue. **State** `REJECTED`, `PARTIAL`, `FAILED` (a failure without a
   later success), `DONE` (every required milestone reached), `OPEN`, or `REPLACED` (another file reissued its
   payments).
5. **Reissue.** A file replaces another when its source names the predecessor or when it carries payments of an
   earlier file (both payments are marked: `OTHER_FILE`). The successor raises `PF_DUP_EXPOSURE` (B) when the original
   reached the bank (delivered, received or accepted) - both files may carry the same payments; an answer of the bank
   for the original after the reissue raises `PF_ORIG_ACK_AFTER_REISSUE` (B) - recognised, never hidden.
6. **Business date.** From the file source; else the local generation date in the file type's time zone, the next day
   from the overnight cut-off (`DAY_CUTOFF`) on, then the next business day of the calendar.
7. **Deadlines.** Clock (`T`): `DUE_TIME` (local) `DAY_OFFSET` business days after the business date, e.g. "accepted by
   10:00 of the next business day". Offset (`O`): `OFFSET_MIN` minutes after the milestone `BASIS` was reached (no
   deadline while the basis has no time). Times are stored in UTC.
8. **Expected versus observed.** Per file type and business date (`ZCA_OPS_PFDAY`): a holiday (`HOLIDAY`), a failed
   read of the file source (`NOT_EVAL` - never "no files"), the day's deadline not reached (`PENDING`), a source that
   is not complete up to the deadline for longer than the stale limit (`STALE`), a valid day without files (`ZERO_OK`,
   `ZERO_OK` = X or no files expected), `OK`, `MISSING`, `PARTIAL`. Each row records expected, observed, the source's
   freshness (as-of) and watermark, completeness and the last valid result.

## 3. Configuration (per site, app `ZUI_CA_OPS_CFG`; templates `config/payfile/`, all inactive)

| Table | Entity | What a site maintains |
|---|---|---|
| `ZCA_OPS_PFTYP` | `PayFileType` | file types: business process (owner), direction, ACK level, one ACK for several files, factory calendar, time zone, overnight cut-off, files expected per business day, zero volume valid, stale limit, days under watch (activation needs module CASHOPS, message 350) |
| `ZCA_OPS_PFSTG` | `PayFileMilestone` | which milestones apply, which are required, deadline kind (clock / offset), due time, business days after the business date, basis and offset, grace minutes |
| `ZCA_OPS_PFMAP` | `PayFileStatusMap` | native status of a source -> milestone and outcome (`OK`, `REJECTED`, `PARTIAL`, `FAILED`, `INFO`); an unmapped value is evidence that moves nothing (message 388) |
| `ZCA_OPS_PFADP` | `PayFileAdapter` | the adapter of each role per file type: source ID, class, setting, source type (`SAP`, `MW`, `BANK`) |

Parameters (area `CA_OPS`, `docs/PARAMETERS.md`): `PF_LOOKBACK_DAYS`, `PF_OVERLAP_MIN`, `PF_OPEN_DAYS`, `PF_STALE_MIN`,
`PF_GRACE_MIN`, `PF_BREACH_RED_MIN`, `PF_AMOUNT_RED` / `PF_AMOUNT_RED_<area>` (`[company code:]currency amount` - an
amount is compared only with a limit of its own currency), `PF_MAX_PAYMENTS`, `PF_MAX_FINDINGS`, `PF_EVIDENCE_MAX`,
`PF_RETENTION_DAYS`.

## 4. Adapters (plug-ins; `ZCL_CA_OPS_FACTORY=>GET_PLUGIN`, interface checked by RTTI, ABAP Unit with doubles)

Every adapter implements `ZIF_CA_OPS_PF_ADAPTER` (`CONFIGURE` with its row) and the interface of its role. Adapters
only read: no posting, no restart or retransmission of a file, no IDoc, no incident in SAP, no outbound call.

| Role | Interface | Delivered (SAP standard) | Site-specific |
|---|---|---|---|
| FILE | `ZIF_CA_OPS_PF_FILE_SRC` | `ZCL_CA_OPS_PF_SRC_DPAYH`: payments of the runs (`DPAYH`: LAUFD, LAUFI, ORIGN, XVORL, PAYNO, SUBNO, BBUKR, RZAWE, HBKID, HKTID, WAERS, RWBTR, DOC1R, GPA1R - confirmed on the reference system) grouped into files by `GROUP` (default BBUKR, RZAWE, HBKID, HKTID); the run key is DPAYH's, never derived from a job name; payment-order methods (`ORDERS`) count without payment document | a middleware's file register, a folder log |
| TRANSFER | `ZIF_CA_OPS_PF_TRANSFER_SRC` | - | middleware hops, a direct upload log |
| ACK | `ZIF_CA_OPS_PF_ACK_SRC` | - (bank formats are site-specific, V180) | the site's acknowledgement records |
| SCHED | `ZIF_CA_OPS_PF_SCHED_SRC` | `ZCL_CA_OPS_PF_SRC_TBTCO`: SAP jobs of the programs of `PROGRAMS` through the job monitor's data access (`TBTCO` / `TBTCP`), status F / A mapped by template rows of source `SAPJOB` | another scheduler's run log |
| STMT | `ZIF_CA_OPS_PF_STMT_SRC` | - | statement lines that carry the file's reference |
| TICKET | `ZIF_CA_OPS_PF_TICKET_SINK` | `ZCL_CA_OPS_PF_TICKET_LOG`: log only (status L, reference LOGGED, message 389) | a site's ticketing (its own outbound connection and approval) |
| CALENDAR | `ZIF_CA_OPS_PF_CALENDAR` | `ZCL_CA_OPS_PF_CALENDAR`: SAP factory calendar (V176); blank ID = every day | a bank holiday table |

The event sources share `ZIF_CA_OPS_PF_EVENT_SRC=>READ_EVENTS` (the role is the interface).

## 5. Ingestion `ZCA_OPS_PF_RUN` (`ZCL_CA_OPS_PF_INGEST`)

Per active file type: every adapter reads from its watermark minus `PF_OVERLAP_MIN` (first read: `PF_LOOKBACK_DAYS`);
files and payments are registered (identity file type + native key; payee masked; at most `PF_MAX_PAYMENTS`, the rest
counted); every record is mapped, matched to its file (native key, the files it covers, payment, batch, payment run and
company code - quality **C**onfirmed / **P**robable, a scheduler job by its business date - probable, or **U**nmatched,
stored as evidence anyway) and stored once (event key = SHA-1 of source, record ID, version, file, payment, milestone);
a repeated bank reference is counted (`REPEAT_NO`); a source that fails is recorded **not evaluated** with its reason and
keeps its watermark. Then every file under watch is evaluated with the health of the sources of its milestones, a file
that became overdue is handed to the ticket sink once, every business day of the watch is evaluated. One unit of work per
file type; the register older than `PF_RETENTION_DAYS` is removed. Test mode writes nothing. Licence module CASHOPS.

## 6. Exception contract

Every finding of the module carries the contract of `docs/EXCEPTION_CONTRACT.md` (`ZIF_CA_OPS_EXC_CONTRACT`): payments
(`ITEM_COUNT`), gross amount and currency (`AMOUNT` / `CURRENCY`, one currency per finding), payments without a known
amount (`UNKNOWN_COUNT`), possible duplicate exposure (`DUP_AMOUNT`, only on `PF_DUP_EXPOSURE` /
`PF_ORIG_ACK_AFTER_REISSUE`, whose gross is 0 - related findings count the gross once), the deadline (`DEADLINE_AT`, UTC)
and its calendar, the stage reached, the responsible user / team / source and the evidence key with its typed rows.

## 7. Findings of `ZCL_CA_OPS_CHK_PAYFILE` (catalogue process `FICA_PAYFILE_ACK`, module CASHOPS)

| Code | When | Severity |
|---|---|---|
| `PF_ACK_MISSING` | the flagship: no acceptance past its deadline | W within the grace minutes, E, B by breach minutes / amount |
| `PF_RECEIPT_MISSING`, `PF_NOT_TRANSFERRED`, `PF_NOT_GENERATED`, `PF_NOT_SETTLED` | the first required milestone missing past its deadline | as above |
| `PF_JOB_FAILED` | the generating job was cancelled (reference = job name / count; one finding, never also "not generated") | E (B by amount) |
| `PF_TRANSFER_FAILED` | a transfer hop failed and no later success | E (B by amount) |
| `PF_ACK_REJECTED`, `PF_ACK_PARTIAL`, `PF_ACK_CONFLICT` | rejected, partly accepted, accepted and rejected | E (B by amount) |
| `PF_DUP_EXPOSURE`, `PF_ORIG_ACK_AFTER_REISSUE` | reissue after the original reached the bank; the bank answered the original after the reissue | B |
| `PF_STAGE_LATE` | a milestone reached after its deadline (no open issue) | I |
| `PF_FILE_MISSING` | a business day with fewer files than expected | E |
| `PF_NOT_EVALUATED`, `PF_SOURCE_STALE` | a source failed / a day stale - the check is partial, nothing auto-resolved | W |
| `PF_MORE_FILES` | more than `PF_MAX_FINDINGS` files (the rest unlisted, partial) | W |

A file whose milestone is unknown gives no verdict. **Job monitor:** a cancelled generating job is one finding of this
check (`PF_JOB_FAILED`, never also `PF_NOT_GENERATED`); its `REFERENCE` is the job monitor's object key of the same job
(name / count) and its evidence links the job (`S4_BACKGROUND_JOB`, intent `ZCaOpsJob`). The alert correlation
(`ZCA_OPS_CORR`) keys on object key, object type, groups, rule and check code - not on the reference - so the two
findings of one job are not yet one alert (decision D-K3).

## 8. Worklist `ZUI_CA_OPS_PAYFILE`

`ZC_CA_OpsPayFile` (list report and object page; base `ZR_CA_OpsPayFile`, extension point `PAYFILE`), facets
*Where it stopped*, *Who owns the response*, *Affected payments* (`ZC_CA_OpsPfPayment`), *Stage timeline*
(`ZC_CA_OpsPfMilestone`), *Evidence* (`ZC_CA_OpsPfEvidence`), payment run and job, acknowledgement, reissue, evaluation;
`ZC_CA_OpsPfDay` (expected versus observed); overview card `ZC_CA_OpsPfCard` (open files by next milestone, amount per
currency; aggregated in the database). Navigation by intent: semantic objects `ZCaOpsException`, `ZCaOpsJob`,
`ZCaOpsPaymentTrace` - shown where the site's launchpad maps them. Read access: DCLs with ZCA_OPS 03 for the area and
the company code. The exceptions app shows the contract (facet *Payments, deadline and owner*) and the evidence rows of
any adopting module (`ZC_CA_OpsFindEvidence`).

## 9. Two integration setups, no product edits

| | Setup 1: a site with a middleware (the first consumer's overlay) | Setup 2: example XX (`examples/payfile_xx`, never seeded) |
|---|---|---|
| File source | delivered `DPAYH` adapter (or the site's file register) | delivered `DPAYH` adapter (`GROUP=BBUKR,RZAWE,HBKID`, payment orders `T`) |
| Scheduler | SAP jobs (`ZCL_CA_OPS_PF_SRC_TBTCO`) | XX's own scheduler run log (`ZCL_XX_PF_SCHED_SRC`) |
| Transfer | the middleware's hops (the site's class) | no middleware: a folder log of the upload (`ZCL_XX_PF_FOLDER_SRC`) |
| Acknowledgement | the site's acknowledgement records | XX's bank acknowledgement table (`ZCL_XX_PF_ACK_TABLE`, payment level) |
| Wiring | adapter rows + status mappings of the site | `examples/payfile_xx/config/*.csv` |

Proof (house check `payfile`, `tools/payfile.py`; root test `tools/tests/test_payfile.py`):

- the fixtures (section 10) give the expected and **identical** business results through the test profile with a
  middleware and through XX's profile (and, in the first consumer's repository, through its profile);
- the XX classes name no product class - only `ZIF_CA_OPS_PF_*` interfaces and `ZCX_CA_OPS_ERROR` - and every adapter
  row names a class that implements its role; no product object names an XX object;
- `tools/payfile.py --abaplint <binary>` compiles XX against the product (`examples/payfile_xx/abaplint.json`, 0 issues);
- ABAP Unit `ZCL_CA_OPS_PF_INGEST` (`two_setups_same_result`) runs the flagship through two setups of different
  sources and statuses and asserts the same state, stage, next milestone, overdue minutes and milestones.

## 10. Fixtures

`config/payfile/fixtures.json`: acknowledgement missing (two currencies), late, payment-level partial, reissued with a
late answer for the original, duplicate acknowledgement, accepted then rejected, overnight cut-off, holiday, stale source,
cancelled job, not transferred within the grace minutes, one acknowledgement for two files, the amount limit of a
currency and company code; days: holiday, valid zero volume, stale, not evaluated, missing, OK, pending.

## 11. Limits

- Nothing activated; SAP field names confirmed on the reference system only for `DPAYH`, `TBTCO` (V171-V175: semantics).
- The delivered file source groups payments by run and fields; the identity of the real payment medium (`PMF_KEY`) is
  not used (V174). A site with a file register should plug its own file source.
- Acknowledgement formats, transfer hops and statement references are always site adapters (V180).
- The worklist's object key of a file is file type / native key / currency within 70 characters; a longer native key is
  cut, so its open-exception columns may stay empty (V178).
- Evidence rows: at most `PF_EVIDENCE_MAX` per finding; payments: at most `PF_MAX_PAYMENTS` per file (then partial).

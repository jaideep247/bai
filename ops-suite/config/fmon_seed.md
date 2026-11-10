# FMON — example customizing rows (EXAMPLES — CONFIRM BEFORE TRANSPORT)

> **First principle:** every row below is an example built from the job schedule wiki and the landscape facts; none of it has been checked against PS4.
> **Analogy:** a pre-filled order form — the layout is right, but every line has to be ticked by someone who knows the stock.

Legend: `‹SE11›` = field name of an existing custom table that is **not known** (structure unverified). Fill it from SE11 in Phase 0. The engine validates every name against the DDIC at runtime and refuses unknown names (messages 200–203), so a wrong guess fails loudly, never silently.

## ZCD_FMON_IFACE (interface definition)

`NAME_PATTERN` is **PCRE matched to the complete file name, case ignored** (user decision 2026-11-06), e.g.
`ACH_PNC_[0-9]{8}_.*\.txt` - escape a literal dot as `\.`; the row with the most literal characters wins. The
configuration app refuses a pattern that does not compile (message 418). Before activating a pattern, run
`ZCD_OPS_PATTERN_CHECK` (area FMON_FILE) with it as ad-hoc pattern: it lists the file names of the last days the
pattern captures and the ones no pattern captures.

| IFACE_ID | DIR | FILE_TYPE | SOURCE_SYS | TARGET_SYS | PAY_METHOD | LOB | BANK_KEY | NAME_PATTERN | MIN_BYTES | MAX_BYTES | ACK_EXPECTED | ACK_LEVEL | OWNER | ACTIVE |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| ACH_PNC_DISB_OUT | O | PAYMENT | * | PRISM | ACH | * | PNC | `‹confirm PCRE›` | 1 | 0 | X | PAYMENT | ‹team› | X |
| WIRE_JPMC_OUT | O | PAYMENT | * | PRISM | WIRE | * | ‹bank identifier as in the statement› (JPMC) | `‹confirm PCRE›` | 1 | 0 | X | PAYMENT | ‹team› | X |
| PAYREQ_PRISM_IN | I | API | PRISM | SAP | * | * | * | (blank: API calls, no file name) | 0 | 0 | | | ‹payment engine RTB› | X |
| CHECK_POSPAY_OUT | O | POSPAY | * | PRISM | CHECK | * | ‹bank› | `‹confirm PCRE›` | 1 | 0 | ‹confirm› | FILE | ‹team› | X |
| ACH_COLL_OUT | O | PAYMENT | * | PRISM | ACH | * | PNC | `‹confirm PCRE›` | 1 | 0 | X | FILE | ‹team› | X |
| BLACKLINE_OUT | O | OTHER | * | BLACKLINE | | * | | `‹confirm PCRE›` | 1 | 0 | (blank — no ACK) | | ‹team› | X |
| STRIPE_PAYOUT_IN | I | OTHER | * | SAP | CARD | * | | `‹confirm PCRE›` | 1 | 0 | (blank — no ACK) | | ‹team› | X |
| BAI_JPMC_IN | I | STATEMENT | * | SAP | | * | ‹bank identifier as in the statement› (JPMC) | `‹confirm PCRE›` | 1 | 0 | | | ‹team› | X |
| BAI_BOA_IN | I | STATEMENT | * | SAP | | * | ‹bank identifier as in the statement› (BOA) | `‹confirm PCRE›` | 1 | 0 | | | ‹team› | X |
| ACH_RET_PNC_IN | I | RETURNS | * | SAP | ACH | * | PNC | `‹confirm PCRE›` | 1 | 0 | | | ‹team› | X |
| NOC_PNC_IN | I | NOC | * | SAP | ACH | * | PNC | `‹confirm PCRE›` | 1 | 0 | | | ‹team› | X |
| CHECK_PRINT_IRIS_OUT | O | OTHER | * | IRIS | CHECK | * | ‹bank› | `‹confirm PCRE›` | 1 | 0 | (blank — no bank ACK) | | ‹team› | X |

**BANK_KEY (user decision 2026-11-07).** `BANK_KEY` is filled exactly as the bank identifies itself in its bank statement (the sender / bank identifier the statement carries — e.g. the BAI2 group-header originator identification, usually the ABA routing number, 9 characters; a BIC, 8 or 11 characters, for a CAMT statement — take it from an imported statement of that bank), **not** a short name such as JPMC / BOA (these stay only as a readable comment in brackets). The same value goes into `ZCD_EBS_ACCT-BANK_KEY` of every payment engine account of that bank, into the statement interface row (`BAI_JPMC_IN`, `BAI_BOA_IN`), into every other interface row of that bank (`WIRE_JPMC_OUT`: the PRISM queue per bank, `FMON_PRISM_THROTTLE_SCOPE` C, groups by it) and into bank-specific entries of the posting area `ZBTM` (key BANK_KEY, was ZCD_BTC_MAP; `*` = every bank). The field is CHAR 15 on both tables (`ZCD_EBS_ACCT`, `ZCD_FMON_IFACE`) and 15 characters in ZBTM (VERIFY-SE11 that the TFK033D key holds it, `docs/FICA_Posting_Areas.md` §4): a routing number (9) or BIC (11) fits; a longer identifier would need a DDIC change. The FEB adapter finds the accounts of an interface by this value (condensed, upper case) — a different spelling in one table makes every account of the bank "not imported". PNC rows: same rule once PNC statements are monitored.

Landscape facts applied: disbursements are acknowledged per payment (`ACK_LEVEL = PAYMENT`), collections per file (`FILE`); Stripe payout, cost centre, BlackLine and GL OFSAA files have **no** ACK (`ACK_EXPECTED` blank). A source-specific row (e.g. `SOURCE_SYS = PCLM`) is only needed when that source differs (other SLA, pattern or owner); otherwise the `*` row serves every source and LOB.

## ZCD_FMON_SLA

Since the table consolidation of 2026-11-08 one table holds both kinds of stage SLA, key IFACE_ID + STAGE + KIND + DAY_TYPE: `DURATION` (below: the stage within MAX_MINUTES of its basis - P previous stage, G generation; DAY_TYPE `*`; check `ZCL_CD_FMON_CHK_SLA`) and `DEADLINE` (next section, was `ZCD_FMON_DEADL`: the stage by DUE_TIME of a business day; check `ZCL_CD_FMON_CHK_DEADLINE`). The configuration app checks each kind (messages 417 / 422 / 423 / 413): a DURATION row needs MAX_MINUTES > 0, DAY_TYPE `*` and no DUE_TIME; a DEADLINE row needs DUE_TIME, one of the deadline stages and a day type, and no MAX_MINUTES / BASIS. Each check reads only its own kind.

| IFACE_ID | STAGE | KIND | DAY_TYPE | MAX_MINUTES | BASIS | DUE_TIME | SEVERITY | Note (DESCRIPTION) |
|---|---|---|---|---|---|---|---|---|
| ACH_PNC_DISB_OUT | SENT_TO_PRISM | DURATION | * | 30 | P | | E | PRISM pick-up after generation |
| PAYREQ_PRISM_IN | FULLY_PROCESSED | DURATION | * | 60 | P | | E | request received but no SUCCESS row within an hour ‹confirm› |
| ACH_PNC_DISB_OUT | FORWARDED_TO_BANK | DURATION | * | 60 | P | | W | only if a source reports the forward |
| ACH_PNC_DISB_OUT | ACK_RECEIVED | DURATION | * | 240 | G | | E | ‹confirm with bank cut-off› |
| WIRE_JPMC_OUT | ACK_RECEIVED | DURATION | * | 30 | G | | E | requirements baseline: "wire ack within 30 minutes" |
| ACH_RET_PNC_IN | FULLY_PROCESSED | DURATION | * | 480 | G | | E | FP09 lot complete same day ‹confirm› |
| NOC_PNC_IN | FILE_LOADED | DURATION | * | 60 | P | | W | |
| ACH_PNC_DISB_OUT | PRISM_RECEIVED | DURATION | * | 15 | P | | E | PRISM status API: PRISM confirms receipt within 15 min of SENT_TO_PRISM |
| ACH_PNC_DISB_OUT | PRISM_DELIVERED | DURATION | * | 5 | P | | E | **base** 5 min from PRISM's receipt + PRISM throttle 2 min × ACH / wire files ahead in the queue (added by FMON, see below) ‹confirm base with PRISM› |
| WIRE_JPMC_OUT | PRISM_RECEIVED | DURATION | * | 15 | P | | E | |
| WIRE_JPMC_OUT | PRISM_DELIVERED | DURATION | * | 5 | P | | E | base 5 min + throttle (wires are throttled like ACH) ‹confirm› |
| BAI_JPMC_IN | FILE_RECEIVED | DURATION | * | 30 | P | | E | SAP receives the statement within 30 min of PRISM_DELIVERED (inbound PRISM evidence) |

Every SLA row is delivered with `ACTIVE = X`. New rows only by customizing transport from DV1 (`RAP_Config_Apps.md` §2, user decision 2026-11-07); in PS4 support may edit an existing row and switch it off with `ACTIVE` blank — never create or delete there.

## ZCD_FMON_SLA, kind DEADLINE (stage reached by a clock time of a business day — user requirement 2026-11-07; was ZCD_FMON_DEADL)

"Alert if BAI is not processed until 10 AM" (JPMC and BOA, **10:00 US Central** — `FMON_TIME_ZONE` = CST, Central time with US daylight saving, i.e. 10:00 local all year; normal business days). `DAY_TYPE` `*` = every business day; a `MONTH_END` / `RETURNS_DAY` row would win on such a day (fallback NORMAL, then `*` - unchanged by the consolidation). Evaluated only on a business day whose `ZCD_FMON_CAL` row expects at least one file — never on a holiday. A similar alert is a new DEADLINE row here (and, if needed, a rule in `ZCA_OPS_ALRULE`), created in DV1 on a customizing request, tested in QA1 and transported to PS4; in PS4 support only edits existing rows (due time, severity, ACTIVE) (`Operations_Runbook.md` §5h).

| IFACE_ID | STAGE | KIND | DAY_TYPE | MAX_MINUTES | BASIS | DUE_TIME | SEVERITY | ACTIVE | DESCRIPTION |
|---|---|---|---|---|---|---|---|---|---|
| BAI_JPMC_IN | FULLY_PROCESSED | DEADLINE | * | | | 10:00 | E | X | JPMC BAI received, imported and posted by 10:00 |
| BAI_BOA_IN | FULLY_PROCESSED | DEADLINE | * | | | 10:00 | E | X | BOA BAI received, imported and posted by 10:00 |

At 10:00 the finding `STAGE_DEADLINE_MISSED` names the earliest missing step (GROUP2): `NOT_RECEIVED` (no file, no statement), `NOT_IMPORTED` (received, statements of x of y payment engine accounts in FEBKO), `NOT_POSTED` (every account imported, n of m in-scope FEBEP lines not posted), with bank and statement date. Stages a deadline may name (configuration app): FILE_RECEIVED, FILE_LOADED, FULLY_PROCESSED, GENERATED_IN_SAP, ACK_RECEIVED.

SLA rows for the other PRISM-routed flows (`docs/PRISM_Status_API.md` §8) are **to configure** once their interface rows exist; no example is given for unseeded interfaces.

**PRISM throttle (confirmed by the user 2026-11-06): PRISM throttles ACH and wire files at 2 minutes per file before sending them to the bank; positive pay and stop pay are not throttled.** **One queue per bank** (JPMC, BOA, PNC … each wait 2 minutes between their own files; files to different banks do not wait for each other — confirmed by the user 2026-11-06, scope `C`); the gap is **1–2 minutes per file** (parameter default 2) and is measured from the PRISM status API timestamps (PRISM_RECEIVED → PRISM_DELIVERED) after go-live, then `FMON_PRISM_THROTTLE_MIN` is tuned. Maintain the `PRISM_DELIVERED` / `FORWARDED_TO_BANK` row of a throttled interface as the **base** time PRISM needs for one file; FMON adds `FMON_PRISM_THROTTLE_MIN` × the ACH / wire files queued ahead of it (same business date, queue scope `FMON_PRISM_THROTTLE_SCOPE`), capped at a queue of `FMON_PRISM_QUEUE_MAX` files (`docs/FMON_FILE_MONITORING.md` §A3a). Worked example for `ACH_PNC_DISB_OUT`:

| Stage | Row | Allowed for a file alone | Allowed for the 5th of 5 files handed over together |
|---|---|---|---|
| SENT_TO_PRISM → PRISM_RECEIVED | 15 P | 15 min | 15 min (PRISM's receipt is not throttled) |
| PRISM_RECEIVED → PRISM_DELIVERED | 5 P | 5 min | 5 + 4 × 2 = 13 min |
| ACK_RECEIVED | 240 G | 240 min | 240 + 8 = 248 min (measured from generation, so the queue wait is inside it) |
| ACK_RECEIVED (if configured with basis P) | 60 P | 60 min after delivery | 60 min after delivery (the wait is already behind the basis) |

Throttled = outbound interface with `PAY_METHOD` in `FMON_PRISM_THROTTLE_METHODS`: `ACH_PNC_DISB_OUT`, `ACH_COLL_OUT` (ACH), `WIRE_JPMC_OUT` (WIRE). `CHECK_POSPAY_OUT` (`CHECK`), `BLACKLINE_OUT`, inbound rows: not throttled. A future stop pay row must not use `ACH` / `WIRE` as payment method.

## ZCD_FMON_CAL (expected files; times in `FMON_TIME_ZONE` = US Central)

| IFACE_ID | DAY_TYPE | EXPECTED_COUNT | WINDOW_FROM | WINDOW_TO | FCAL_ID | Source of the example |
|---|---|---|---|---|---|---|
| BAI_JPMC_IN | NORMAL | 1 | 08:00 | 08:20 | ‹US› | wiki: BAI JPMC 8.20 am |
| BAI_BOA_IN | NORMAL | 1 | 08:00 | 08:20 | ‹US› | wiki: BAI BOA 8.20 am |
| BAI_JPMC_IN | HOLIDAY | 0 | | | ‹US› | no statement on bank holidays ‹confirm› |
| BAI_BOA_IN | HOLIDAY | 0 | | | ‹US› | no statement on bank holidays ‹confirm› |
| WIRE_JPMC_OUT | NORMAL | 1 | 13:30 | 14:00 | ‹US› | wiki: WIRE CORP 1.30 pm |
| ACH_PNC_DISB_OUT | NORMAL | 3 | 17:00 | 19:30 | ‹US› | wiki: ACH PNC & PUB evening 5/6/7 pm |
| ACH_PNC_DISB_OUT | MONTH_END | 4 | 17:00 | 21:00 | ‹US› | example only |

Every calendar row is delivered with `ACTIVE = X` (new rows by transport from DV1; in PS4 an existing row is edited or switched off, never created or deleted).

## ZCD_FMON_SRC (legacy source adapters — field names to be filled from SE11)

| SRC_ID | IFACE_ID | TABLE_NAME | FILE_KEY_FIELD | FILE_NAME_FIELD | DATE_FIELD | TIME_FIELD | TS_FIELD | STATUS_FIELD | COUNT_FIELD | AMOUNT_FIELD | SIZE_FIELD | ITEM_KEY_FIELD | DEFAULT_STAGE | ADAPTER_CLASS | GROUP_FIELDS |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| REGUT | (blank: by pattern) | ZCDT_REGUT | ‹SE11› | ‹SE11› | ‹SE11› | ‹SE11› | | ‹SE11 or blank› | ‹SE11› | ‹SE11› | ‹SE11› | | GENERATED_IN_SAP | (blank) | ‹SE11: payment run, e.g. LAUFD,LAUFI,HBKID› |
| ACHACK | ACH_PNC_DISB_OUT | ZCD_ACH_ACK | ‹SE11› | ‹SE11› | ‹SE11› | ‹SE11› | | ‹SE11› | ‹SE11› | ‹SE11› | | ‹SE11 payment key, if one row per payment› | | (blank) | |
| WIREACK | WIRE_JPMC_OUT | ZCD_WIRE_ACK | ‹SE11› | ‹SE11› | ‹SE11› | ‹SE11› | | ‹SE11› | | ‹SE11› | | ‹SE11 wire reference› | | (blank) | |
| CHKHIST | CHECK_POSPAY_OUT | ZCD_CHECK_HIST | ‹SE11› | ‹SE11› | ‹SE11› | ‹SE11› | | ‹SE11› | | | | | | (blank) | |
| ACHRTRV | ACH_RET_PNC_IN | ZCD_ACH_RTRV_LOG | ‹SE11› | ‹SE11› | ‹SE11› | ‹SE11› | | ‹SE11› | ‹SE11› | | | | | (blank) | |
| STRPPOUT | STRIPE_PAYOUT_IN | ZCD_STRP_POUT_LOG | ‹SE11› | ‹SE11› | ‹SE11› | ‹SE11› | | ‹SE11› | ‹SE11› | ‹SE11› | | | | (blank) | |
| PAYREQ | PAYREQ_PRISM_IN | ZCD_PAYM_REQ_LOG | ‹SE11 request key› | (blank) | ‹SE11 date› | ‹SE11 time› | | ZZ_STATUS | | ‹SE11 amount or blank› | | | FILE_RECEIVED | (blank) | |
| FEB | (blank: every inbound STATEMENT interface with a bank key) | FEBKO | (blank) | (blank) | (blank) | (blank) | (blank) | (blank) | (blank) | (blank) | (blank) | (blank) | (blank) | ZCL_CD_FMON_ADAPTER_FEB | |
| PRISM | (blank: `interfaceId` or name pattern) | ZCD_FMON_PRISM | (blank) | FILE_REF | (blank) | (blank) | OCCURRED_AT | MILESTONE | (blank) | (blank) | (blank) | (blank) | (blank) | ZCL_CD_FMON_ADAPTER_PRISM | |

**Regenerated files (facts confirmed by the user 2026-11-07).** PRISM rejects a file name it has already received; a file PRISM could not deliver (to the bank, or the cheque print file to IRIS when the PRISM → IRIS call fails) is regenerated by SAP **under a new name for the same payments**. `GROUP_FIELDS` of the generating source (here `REGUT`) names the fields of the payment run that produced the file — comma list, at most 4, in a fixed order (e.g. `LAUFD,LAUFI,HBKID`; field names **VERIFY-SE11** on `ZCDT_REGUT`, validated against the DDIC at runtime; the fields must be approved in `ZCD_OPS_TABWL` (FMON / SOURCE) like every other field). The values joined by `/` are the file's generation group (`ZCD_FMON_FILE-GEN_GROUP`, the only stored link); files of the same interface and group are generations of the same payments (`docs/FMON_FILE_MONITORING.md` §A2 rule 9). Include the house bank when one payment run produces one file per house bank — two different files of one group would be reported as `FILE_REGENERATED_NOT_FAILED`. Blank (every other row) = no link, behaviour unchanged.

**Imported bank statements (FEB adapter, 2026-11-07).** The `FEB` row is confirmed (the suite's own adapter; `TABLE_NAME = FEBKO` documents the read, no field names, no `ZCD_FMON_SRCMAP` rows and no `ZCD_OPS_TABWL` row needed: the statement evidence is read by the EBS repository with static SQL, `ZIF_CD_EBS_STMT_EVIDENCE`). Per interface with `BANK_KEY` (the bank identifier as in the statement — the same value as `ZCD_EBS_ACCT-BANK_KEY`) and working business date B it reads the statements of the active `ZCD_EBS_ACCT` accounts with the same `BANK_KEY` dated the `FMON_FEB_STMT_OFFSET`-th working day before B (1: Monday's file carries Friday's statement — confirmed 2026-11-07) and reports the day's file instance: FILE_RECEIVED (some accounts imported), FILE_LOADED (all imported; posting state not read or read capped), PARTIALLY_PROCESSED (in-scope entries not posted, unprocessed count = entries), FULLY_PROCESSED. Evidence-only when nothing is imported. When another source (PRISM, load log) registered exactly one instance of the interface and day, the statement attaches to it; otherwise the adapter's own reference `FEB/<bank>/<statement date>`.

**PRISM status API (`docs/PRISM_Status_API.md`).** The row above is confirmed (the suite's own table, `ddic/fmon/zcd_fmon_prism.tabl.ddl`). `ADAPTER_CLASS` must be `ZCL_CD_FMON_ADAPTER_PRISM`: the 5-minute run then reads only events no instant unit processed (`PROCESSED_AT` initial, window on `RECEIVED_AT`) and the instant unit finds its source by this class. `FILE_NAME_FIELD = FILE_REF` gives the generic key rules (upper-case canonical name, A100 digest for long names, business date from `OCCURRED_AT` in `FMON_TIME_ZONE`; the file instance by the file generation identity, `FMON_FILE_MONITORING.md` §A2 rule 8). `COUNT_FIELD` / `AMOUNT_FIELD` stay blank on purpose: PRISM's counts are evidence in `ZCD_FMON_PRISM`, not the file's control figures. An `interfaceId` sent by PRISM selects the interface; otherwise the name pattern decides; no match = `UNMAPPED_FILE`. For correlation the SAP-side source of the same flow must key the file by its name (`FILE_KEY_FIELD` blank or the name field), or PRISM must send the SAP file key.

**PRISM payment requests (USAA reference).** Each request is one monitored "file" of interface `PAYREQ_PRISM_IN` keyed by the request reference (`FILE_KEY_FIELD`; the FMON object key is that reference in upper case — the PRISM handled-manually app resolves the exception by it). Confirmed: status field `ZZ_STATUS`, processed = `SUCCESS`, and the highest `COUNTER` is never used — the state machine makes `FULLY_PROCESSED` final, so a failed attempt written after the success cannot downgrade the request (tests `success_wins_over_later_fail`, `success_after_fail_wins`). The `SOURCE` field separates PCLM, ORCI, … — partition by a `ZCD_FMON_SRC` row per source with a condition on `SOURCE` when the adapter supports it, otherwise one interface per source ‹confirm›.

`FILE_KEY_FIELD` must be identical in every table of the same file (e.g. a run/file ID). A file instance is **one per file generation** (design review 2026-11-07, refining audit A49): fixed by the file's first evidence (outbound generation, inbound first of PRISM receipt / delivery and SAP receipt) with that business date; later rows of the same reference (receipt, load, ACK, NACK, return) attach to it whatever their own date — a delivery at 23:58 CST and a receipt at 00:03 CST are one file. The same constant file name on another day is a new instance when it is a new generation (first evidence of a stage the earlier instance already reached), never a merge; undated responses attach to the latest earlier instance, and when several instances qualify the engine raises `FILE_REF_AMBIGUOUS` instead of guessing. Every adapter must therefore supply `DATE_FIELD` (or `TS_FIELD`).

`ITEM_KEY_FIELD` (audit A39): payment key of a response table with one row per payment. When it is set, ACK/NACK counts are distinct payments (re-sent acknowledgements are not double counted) and accumulate across runs; when blank, a file-level row's `COUNT_FIELD` is taken as the acknowledged count. A file without any reported count is *unknown* and the ACK-count match is not evaluated; a reported zero is checked.

Rows whose count, amount, size or date cannot be converted are quarantined (`MALFORMED_SOURCE_ROW`, audit A52) and never counted.

## ZCD_FMON_SRCMAP (status values — ‹confirm with each table's domain›)

| SRC_ID | STATUS_VALUE | STAGE |
|---|---|---|
| REGUT | ‹value: sent› | SENT_TO_PRISM |
| ACHACK | ‹value: accepted› | ACK_RECEIVED |
| ACHACK | ‹value: rejected› | NACK_REJECTED |
| WIREACK | ‹value: accepted› | ACK_RECEIVED |
| WIREACK | `*` | NACK_REJECTED (only if every other value is a rejection — confirm) |
| ACHRTRV | ‹value: received› | FILE_RECEIVED |
| ACHRTRV | ‹value: loaded› | FILE_LOADED |
| ACHRTRV | ‹value: error› | FAILED |
| PAYREQ | SUCCESS | FULLY_PROCESSED |
| PAYREQ | ‹confirm failure values› | FAILED |
| PAYREQ | `*` | FILE_RECEIVED (any other status: request arrived, not yet processed) |
| PRISM | RECEIVED | PRISM_RECEIVED |
| PRISM | DELIVERED | PRISM_DELIVERED |
| PRISM | FAILED | PRISM_FAILED |

The three PRISM rows are confirmed (wire values of the API). `PRISM_*` stages fit both directions; their order per direction is in `docs/FMON_FILE_MONITORING.md` §A2.

## ZCD_OPS_TABWL, area FMON, purpose SOURCE (tables approved for the dynamic reader — audit A51)

Since the table consolidation of 2026-11-08 the approved tables of every reader are one core table, `ZCD_OPS_TABWL` (core configuration app *Alerting and approved tables* → *Approved tables per reader*; was `ZCD_FMON_TABWL`). The FMON reader reads only the rows with `PE_AREA = FMON` and `PURPOSE = SOURCE`. Every table named in `ZCD_FMON_SRC` or `ZCD_FMON_LOTCFG` (and every payment trace source, `Payment_Trace.md` §9) must be approved here, and the batch user needs `S_TABU_NAM` (ACTVT 03, TABLE = the name) for it; otherwise the read is refused (messages 244 / 245 / 249). `FIELD_NAME` **blank** approves every field of the table (was `*`); list fields one row each to narrow it. `APPROVED_BY` = the security reviewer of the row.

| PE_AREA | PURPOSE | TABLE_NAME | FIELD_NAME | ACTIVE | APPROVED_BY | DESCRIPTION |
|---|---|---|---|---|---|---|
| CD_FMON | SOURCE | ZCDT_REGUT | (blank) | X | `<security reviewer>` | Generated payment files |
| CD_FMON | SOURCE | ZCD_ACH_ACK | (blank) | X | `<security reviewer>` | ACH bank acknowledgements |
| CD_FMON | SOURCE | ZCD_WIRE_ACK | (blank) | X | `<security reviewer>` | Wire bank acknowledgements |
| CD_FMON | SOURCE | ZCD_CHECK_HIST | (blank) | X | `<security reviewer>` | Check / positive pay history |
| CD_FMON | SOURCE | ZCD_ACH_RTRV_LOG | (blank) | X | `<security reviewer>` | ACH returns retrieval log |
| CD_FMON | SOURCE | ZCD_STRP_POUT_LOG | (blank) | X | `<security reviewer>` | Stripe payout log |
| CD_FMON | SOURCE | ZCD_PAYM_REQ_LOG | (blank) | X | `<security reviewer>` | PRISM payment request log |
| CD_FMON | SOURCE | DFKKNRK | (blank) | X | `<security reviewer>` | NOC lot header |
| CD_FMON | SOURCE | DFKKNRP | (blank) | X | `<security reviewer>` | NOC lot items |
| CD_FMON | SOURCE | DFKKRP | (blank) | X | `<security reviewer>` | Returns lot items |
| CD_FMON | SOURCE | ‹SE11: returns lot header› | (blank) | X | `<security reviewer>` | Returns lot header |
| CD_FMON | SOURCE | ZCD_FMON_PRISM | (blank) | X | `<security reviewer>` | PRISM status events (the PRISM adapter reads it through its own DAO; the row keeps the approval list complete and covers a generic source on the table) |

The HCK rows of the same table (purposes `READ` and `DRIFT`) are in `config/hck_seed.md` §5 / §6; a row of another area or purpose never approves the FMON reader.

## ZCD_FMON_LOTCFG

| IFACE_ID | LOT_TYPE | HDR_TABLE | HDR_LOT_FIELD | HDR_LINK_FIELD | ITEM_TABLE | ITEM_LOT_FIELD | ITEM_KEY_FIELD | ITEM_STATUS_FIELD | ITEM_LINK_FIELD | LINK_BY | DONE_VALUES | NOC_SLA_DAYS |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| * | NOC | DFKKNRK | KEYN1 | ‹SE11: file reference on DFKKNRK› | DFKKNRP | KEYN1 | POSNA | ‹SE11: item status› | | N | ‹confirm› | 6 |
| * | RETURNS | ‹SE11: returns lot header› | ‹SE11› | ‹SE11› | DFKKRP | ‹SE11› | ‹SE11› | ‹SE11› | | N | ‹confirm› | 0 |

Confirmed facts used: DFKKNRK / DFKKNRP exist, lot key KEYN1, item key POSNA; DFKKRP exists (DFKKRP-SELW1 = DFKKOP-AUGBL). DFKKRNIT / DFKKRAFT do **not** exist and must never be configured. Every other DFKK* field above is unverified.

## ZCD_FMON_CHK

| CHECK_ID | CLASS_NAME | SEVERITY | PARAMS |
|---|---|---|---|
| F_MISSING | ZCL_CD_FMON_CHK_MISSING | E | GRACE_MIN=60 |
| F_LATE | ZCL_CD_FMON_CHK_LATE | W | GRACE_MIN=60 |
| F_PRISM | ZCL_CD_FMON_CHK_SLA | E | STAGE=SENT_TO_PRISM;LATE_SEVERITY=W |
| F_BANKACK | ZCL_CD_FMON_CHK_SLA | E | STAGE=ACK_RECEIVED;LATE_SEVERITY=W |
| F_SLA | ZCL_CD_FMON_CHK_SLA | E | STAGE=FULLY_PROCESSED |
| F_REJECT | ZCL_CD_FMON_CHK_REJECT | E | |
| F_ACKMATCH | ZCL_CD_FMON_CHK_ACK_MATCH | E | TOLERANCE=0.01 |
| F_DUP | ZCL_CD_FMON_CHK_DUPLICATE | E | ORIGIN_ROWS=Y |
| F_SIZE | ZCL_CD_FMON_CHK_SIZE | E | |
| F_LOT | ZCL_CD_FMON_CHK_LOT | E | |
| F_NOCAGE | ZCL_CD_FMON_CHK_NOC_AGING | E | |
| F_PRISMRCV | ZCL_CD_FMON_CHK_SLA | E | STAGE=PRISM_RECEIVED;LATE_SEVERITY=W |
| F_PRISMDLV | ZCL_CD_FMON_CHK_SLA | E | STAGE=PRISM_DELIVERED;LATE_SEVERITY=W (also reports PRISM_QUEUE_LONG, W) |
| F_FILERCV | ZCL_CD_FMON_CHK_SLA | E | STAGE=FILE_RECEIVED;LATE_SEVERITY=W |
| F_PRFAIL | ZCL_CD_FMON_CHK_REJECT | E | OUTCOME=PRISM_FAILED |
| F_PRFILE | ZCL_CD_FMON_CHK_PRISM_FILE | W | GRACE_MIN=60 |
| F_DEADLINE | ZCL_CD_FMON_CHK_DEADLINE | E | (none - DEADLINE rows of ZCD_FMON_SLA; row SEVERITY wins) |
| F_REGEN | ZCL_CD_FMON_CHK_REGEN | B | (none) - FILE_REGENERATED_NOT_FAILED: regenerated file while the earlier generation did not fail (possible duplicate payment file) |

`F_PRFAIL` reuses the reject check: with `OUTCOME=PRISM_FAILED` it reports only `PRISM_FAILED` (the existing `F_REJECT` row is unchanged and does not report it, so nothing is doubled); for a file with a generation group it reports `FILE_REPLACED` (information) once a regenerated file exists, `REGENERATION_MISSING` (E) next to `PRISM_FAILED` after `FMON_REGEN_WAIT_MIN`, and `PRISM_DUPLICATE_NAME` (E) instead of `PRISM_FAILED` for an error code of `FMON_PRISM_DUP_NAME_CODES`. `F_REGEN` and `F_PRFAIL` also run in the instant PRISM unit. `F_PRFILE` reports `PRISM_UNKNOWN_FILE` (outbound file only PRISM reported) and `PRISM_NOT_LOADED` (inbound file PRISM delivered, not received in SAP) after `GRACE_MIN` — longer than the 5-minute cycle, so PRISM being faster than SAP's next read is no finding. The instant PRISM unit runs only the SLA, reject and PRISM-file checks.

## FMON parameters — framework `ZCA_PARAM`, area `CD_FMON`

Definitions (value type, limits, delivered default) of every parameter: `config/param_definitions.csv`; example value rows to confirm per landscape: `config/param_values.csv` (format: `param-framework/docs/ONBOARDING.md` section 6a). Maintained in the framework app *Parameter areas* (`ZUI_CA_PARAM`), area `CD_FMON` - ZCD_OPS_PARAM is retired. Examples below differ from the delivered default only where marked ‹ ›.

| Parameter | Example | Meaning |
|---|---|---|
| FMON_LOOKBACK_DAYS | 1 | days read back from legacy tables / files evaluated |
| FMON_OPEN_DAYS | 30 | open or partially processed files kept under watch |
| FMON_DUP_DAYS | 7 | duplicate-file history |
| FMON_TIME_ZONE | CST | **business times are US Central** (user decision 2026-11-07; value row in `config/param_values.csv`, definition default stays UTC): calendar windows, deadlines (`ZCD_FMON_SLA-DUE_TIME` of the DEADLINE rows), business date of timestamps and PRISM events, and the interpretation of legacy date/time fields (`FMON_FILE_MONITORING.md` §A3b — time zone) |
| FMON_FACTORY_CAL | ‹US› | factory calendar when ZCD_FMON_CAL has none |
| FMON_RETURNS_WEEKDAYS | ‹1,2,3,4,5› | weekdays that are ACH returns cycle days |
| FMON_NOC_SLA_DAYS | 6 | NACHA NOC limit in banking days |
| FMON_MAX_ROWS | 50000 | row cap per legacy read; a lot scan reaching it is `LOT_SCAN_TRUNCATED` and derives no lot outcome (audit A38) |
| FMON_PRISM_MAX_BYTES | 16384 | body limit of the PRISM status API (413 above) |
| FMON_PRISM_INSTANT | X | BOOL: X = the instant PRISM unit saves findings and alerts; a value row with blank value = registry only, findings and alerts from the 5-minute run (row delivered so production can switch it) |
| FMON_PRISM_THROTTLE_MIN | 2 | minutes PRISM waits per throttled file before sending it to the bank (user 2026-11-06); `0` = no queue allowance (behaviour before 2026-11-06) |
| FMON_PRISM_THROTTLE_SCOPE | C | `A` = one PRISM queue for all throttled files; `C` = one queue per bank (`ZCD_FMON_IFACE-BANK_KEY`). **C is confirmed and the default** (one PRISM queue per bank, user 2026-11-06) |
| FMON_PRISM_THROTTLE_METHODS | ACH,WIRE | payment methods (`ZCD_FMON_IFACE-PAY_METHOD`) PRISM throttles; positive pay / stop pay are not throttled |
| FMON_PRISM_QUEUE_MAX | 30 | longest PRISM queue (files incl. the file) the allowance covers; a longer one is `PRISM_QUEUE_LONG` (W) |
| FMON_FEB_STMT_OFFSET | 1 | working days from the bank statement date (FEBKO-AZDAT) to the business date of the statement file (FEB adapter): 1 = prior-day statement (Monday file = Friday statement), 0 = same-day. **1 confirmed** (user 2026-11-07: the BAI statement date is the previous business day) |
| FMON_REGEN_WAIT_MIN | 60 | minutes after PRISM_FAILED within which SAP regenerates the file; later `REGENERATION_MISSING` (only for files with a generation group); `0` = off ‹confirm with payment operations› |
| FMON_PRISM_DUP_NAME_CODES | (empty) | PRISM error codes meaning "file name already received" (comma list, whole value, case ignored) — `PRISM_DUPLICATE_NAME` instead of `PRISM_FAILED`; **VERIFY with PRISM**, delivered empty (no read, no such finding) |
| FMON_AGE_BASIS | A | NOC / returns age in working days: `A` counts from the first working day **after** receipt, `N` treats a receipt on a non-working day as received on the next working day (audit A41). If the factory calendar cannot convert the dates the age is unknown: no aging finding, warning 248 instead |

## Alerting

FMON calls the core router (`ZIF_CA_OPS_ALERT~DISPATCH`) once per run. Thresholds, recipients, channels, digest, throttling and quiet hours are rows of `ZCA_OPS_ALRULE` (owned by core), e.g. payment engine area `FMON`, minimum severity `E`, group1 pattern `ACH_.*` (PCRE, complete value, case ignored). FMON keeps no alert configuration of its own.

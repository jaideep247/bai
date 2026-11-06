# FMON — example customizing rows (EXAMPLES — CONFIRM BEFORE TRANSPORT)

> **First principle:** every row below is an example built from the job schedule wiki and the landscape facts; none of it has been checked against PS4.
> **Analogy:** a pre-filled order form — the layout is right, but every line has to be ticked by someone who knows the stock.

Legend: `‹SE11›` = field name of an existing custom table that is **not known** (structure unverified). Fill it from SE11 in Phase 0. The engine validates every name against the DDIC at runtime and refuses unknown names (messages 200–203), so a wrong guess fails loudly, never silently.

## ZCD_FMON_IFACE (interface definition)

| IFACE_ID | DIR | FILE_TYPE | SOURCE_SYS | TARGET_SYS | PAY_METHOD | LOB | BANK_KEY | NAME_PATTERN | MIN_BYTES | MAX_BYTES | ACK_EXPECTED | ACK_LEVEL | OWNER | ACTIVE |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| ACH_PNC_DISB_OUT | O | PAYMENT | * | PRISM | ACH | * | PNC | `‹confirm pattern›` | 1 | 0 | X | PAYMENT | ‹team› | X |
| WIRE_JPMC_OUT | O | PAYMENT | * | PRISM | WIRE | * | JPMC | `‹confirm pattern›` | 1 | 0 | X | PAYMENT | ‹team› | X |
| PAYREQ_PRISM_IN | I | API | PRISM | SAP | * | * | * | (blank: API calls, no file name) | 0 | 0 | | | ‹payment engine RTB› | X |
| CHECK_POSPAY_OUT | O | POSPAY | * | PRISM | CHECK | * | ‹bank› | `‹confirm pattern›` | 1 | 0 | ‹confirm› | FILE | ‹team› | X |
| ACH_COLL_OUT | O | PAYMENT | * | PRISM | ACH | * | PNC | `‹confirm pattern›` | 1 | 0 | X | FILE | ‹team› | X |
| BLACKLINE_OUT | O | OTHER | * | BLACKLINE | | * | | `‹confirm pattern›` | 1 | 0 | (blank — no ACK) | | ‹team› | X |
| STRIPE_PAYOUT_IN | I | OTHER | * | SAP | CARD | * | | `‹confirm pattern›` | 1 | 0 | (blank — no ACK) | | ‹team› | X |
| BAI_JPMC_IN | I | STATEMENT | * | SAP | | * | JPMC | `‹confirm pattern›` | 1 | 0 | | | ‹team› | X |
| BAI_BOA_IN | I | STATEMENT | * | SAP | | * | BOA | `‹confirm pattern›` | 1 | 0 | | | ‹team› | X |
| ACH_RET_PNC_IN | I | RETURNS | * | SAP | ACH | * | PNC | `‹confirm pattern›` | 1 | 0 | | | ‹team› | X |
| NOC_PNC_IN | I | NOC | * | SAP | ACH | * | PNC | `‹confirm pattern›` | 1 | 0 | | | ‹team› | X |

Landscape facts applied: disbursements are acknowledged per payment (`ACK_LEVEL = PAYMENT`), collections per file (`FILE`); Stripe payout, cost centre, BlackLine and GL OFSAA files have **no** ACK (`ACK_EXPECTED` blank). A source-specific row (e.g. `SOURCE_SYS = PCLM`) is only needed when that source differs (other SLA, pattern or owner); otherwise the `*` row serves every source and LOB.

## ZCD_FMON_SLA

| IFACE_ID | STAGE | MAX_MINUTES | BASIS | SEVERITY | Note |
|---|---|---|---|---|---|
| ACH_PNC_DISB_OUT | SENT_TO_PRISM | 30 | P | E | PRISM pick-up after generation |
| PAYREQ_PRISM_IN | FULLY_PROCESSED | 60 | P | E | request received but no SUCCESS row within an hour ‹confirm› |
| ACH_PNC_DISB_OUT | FORWARDED_TO_BANK | 60 | P | W | only if a source reports the forward |
| ACH_PNC_DISB_OUT | ACK_RECEIVED | 240 | G | E | ‹confirm with bank cut-off› |
| WIRE_JPMC_OUT | ACK_RECEIVED | 30 | G | E | master prompt: "wire ack within 30 minutes" |
| ACH_RET_PNC_IN | FULLY_PROCESSED | 480 | G | E | FP09 lot complete same day ‹confirm› |
| NOC_PNC_IN | FILE_LOADED | 60 | P | W | |
| ACH_PNC_DISB_OUT | PRISM_RECEIVED | 15 | P | E | PRISM status API: PRISM confirms receipt within 15 min of SENT_TO_PRISM |
| ACH_PNC_DISB_OUT | PRISM_DELIVERED | 30 | P | E | PRISM delivered to the bank within 30 min of its receipt ‹confirm with PRISM› |
| WIRE_JPMC_OUT | PRISM_RECEIVED | 15 | P | E | |
| WIRE_JPMC_OUT | PRISM_DELIVERED | 15 | P | E | wires are time-critical ‹confirm› |
| BAI_JPMC_IN | FILE_RECEIVED | 30 | P | E | SAP receives the statement within 30 min of PRISM_DELIVERED (inbound PRISM evidence) |

SLA rows for the other PRISM-routed flows (`docs/PRISM_Status_API.md` §8) are **to configure** once their interface rows exist; no example is given for unseeded interfaces.

## ZCD_FMON_CAL (expected files; times in `FMON_TIME_ZONE`)

| IFACE_ID | DAY_TYPE | EXPECTED_COUNT | WINDOW_FROM | WINDOW_TO | FCAL_ID | Source of the example |
|---|---|---|---|---|---|---|
| BAI_JPMC_IN | NORMAL | 1 | 08:00 | 08:20 | ‹US› | wiki: BAI JPMC 8.20 am |
| BAI_BOA_IN | NORMAL | 1 | 08:00 | 08:20 | ‹US› | wiki: BAI BOA 8.20 am |
| BAI_JPMC_IN | HOLIDAY | 0 | | | ‹US› | no statement on bank holidays ‹confirm› |
| WIRE_JPMC_OUT | NORMAL | 1 | 13:30 | 14:00 | ‹US› | wiki: WIRE CORP 1.30 pm |
| ACH_PNC_DISB_OUT | NORMAL | 3 | 17:00 | 19:30 | ‹US› | wiki: ACH PNC & PUB evening 5/6/7 pm |
| ACH_PNC_DISB_OUT | MONTH_END | 4 | 17:00 | 21:00 | ‹US› | example only |

## ZCD_FMON_SRC (legacy source adapters — field names to be filled from SE11)

| SRC_ID | IFACE_ID | TABLE_NAME | FILE_KEY_FIELD | FILE_NAME_FIELD | DATE_FIELD | TIME_FIELD | TS_FIELD | STATUS_FIELD | COUNT_FIELD | AMOUNT_FIELD | SIZE_FIELD | ITEM_KEY_FIELD | DEFAULT_STAGE | ADAPTER_CLASS |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| REGUT | (blank: by pattern) | ZCDT_REGUT | ‹SE11› | ‹SE11› | ‹SE11› | ‹SE11› | | ‹SE11 or blank› | ‹SE11› | ‹SE11› | ‹SE11› | | GENERATED_IN_SAP | (blank) |
| ACHACK | ACH_PNC_DISB_OUT | ZCD_ACH_ACK | ‹SE11› | ‹SE11› | ‹SE11› | ‹SE11› | | ‹SE11› | ‹SE11› | ‹SE11› | | ‹SE11 payment key, if one row per payment› | | (blank) |
| WIREACK | WIRE_JPMC_OUT | ZCD_WIRE_ACK | ‹SE11› | ‹SE11› | ‹SE11› | ‹SE11› | | ‹SE11› | | ‹SE11› | | ‹SE11 wire reference› | | (blank) |
| CHKHIST | CHECK_POSPAY_OUT | ZCD_CHECK_HIST | ‹SE11› | ‹SE11› | ‹SE11› | ‹SE11› | | ‹SE11› | | | | | | (blank) |
| ACHRTRV | ACH_RET_PNC_IN | ZCD_ACH_RTRV_LOG | ‹SE11› | ‹SE11› | ‹SE11› | ‹SE11› | | ‹SE11› | ‹SE11› | | | | | (blank) |
| STRPPOUT | STRIPE_PAYOUT_IN | ZCD_STRP_POUT_LOG | ‹SE11› | ‹SE11› | ‹SE11› | ‹SE11› | | ‹SE11› | ‹SE11› | ‹SE11› | | | | (blank) |
| PAYREQ | PAYREQ_PRISM_IN | ZCD_PAYM_REQ_LOG | ‹SE11 request key› | (blank) | ‹SE11 date› | ‹SE11 time› | | ZZ_STATUS | | ‹SE11 amount or blank› | | | FILE_RECEIVED | (blank) |
| PRISM | (blank: `interfaceId` or name pattern) | ZCD_FMON_PRISM | (blank) | FILE_REF | (blank) | (blank) | OCCURRED_AT | MILESTONE | (blank) | (blank) | (blank) | (blank) | (blank) | ZCL_CD_FMON_ADAPTER_PRISM |

**PRISM status API (`docs/PRISM_Status_API.md`).** The row above is confirmed (the suite's own table, `ddic/fmon/zcd_fmon_prism.tabl.ddl`). `ADAPTER_CLASS` must be `ZCL_CD_FMON_ADAPTER_PRISM`: the 5-minute run then reads only events no instant unit processed (`PROCESSED_AT` initial, window on `RECEIVED_AT`) and the instant unit finds its source by this class. `FILE_NAME_FIELD = FILE_REF` gives the generic key rules (upper-case canonical name, A100 digest for long names, business date from `OCCURRED_AT` in `FMON_TIME_ZONE`, A49). `COUNT_FIELD` / `AMOUNT_FIELD` stay blank on purpose: PRISM's counts are evidence in `ZCD_FMON_PRISM`, not the file's control figures. An `interfaceId` sent by PRISM selects the interface; otherwise the name pattern decides; no match = `UNMAPPED_FILE`. For correlation the SAP-side source of the same flow must key the file by its name (`FILE_KEY_FIELD` blank or the name field), or PRISM must send the SAP file key.

**PRISM payment requests (USAA reference).** Each request is one monitored "file" of interface `PAYREQ_PRISM_IN` keyed by the request reference (`FILE_KEY_FIELD`; the FMON object key is that reference in upper case — the PRISM handled-manually app resolves the exception by it). Confirmed: status field `ZZ_STATUS`, processed = `SUCCESS`, and the highest `COUNTER` is never used — the state machine makes `FULLY_PROCESSED` final, so a failed attempt written after the success cannot downgrade the request (tests `success_wins_over_later_fail`, `success_after_fail_wins`). The `SOURCE` field separates PCLM, ORCI, … — partition by a `ZCD_FMON_SRC` row per source with a condition on `SOURCE` when the adapter supports it, otherwise one interface per source ‹confirm›.

`FILE_KEY_FIELD` must be identical in every table of the same file (e.g. a run/file ID). A file instance is **interface + reference + business date** (audit A49): the same constant file name on another day is a new instance, never a merge. Response rows (ACK, NACK, return) with a business date attach to that day's instance; undated responses attach to the latest earlier instance, and when several open instances qualify the engine raises `FILE_REF_AMBIGUOUS` instead of guessing. Every adapter must therefore supply `DATE_FIELD` (or `TS_FIELD`).

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

## ZCD_FMON_TABWL (tables approved for the dynamic reader — audit A51)

Every table named in `ZCD_FMON_SRC` or `ZCD_FMON_LOTCFG` must be approved here, and the batch user needs `S_TABU_NAM` (ACTVT 03, TABLE = the name) for it; otherwise the read is refused (messages 244 / 245 / 249). `FIELD_NAME = *` approves every field; list fields one row each to narrow it.

| TABLE_NAME | FIELD_NAME | ACTIVE | DESCRIPTION |
|---|---|---|---|
| ZCDT_REGUT | * | X | Generated payment files |
| ZCD_ACH_ACK | * | X | ACH bank acknowledgements |
| ZCD_WIRE_ACK | * | X | Wire bank acknowledgements |
| ZCD_CHECK_HIST | * | X | Check / positive pay history |
| ZCD_ACH_RTRV_LOG | * | X | ACH returns retrieval log |
| ZCD_STRP_POUT_LOG | * | X | Stripe payout log |
| ZCD_PAYM_REQ_LOG | * | X | PRISM payment request log |
| DFKKNRK | * | X | NOC lot header |
| DFKKNRP | * | X | NOC lot items |
| DFKKRP | * | X | Returns lot items |
| ‹SE11: returns lot header› | * | X | Returns lot header |
| ZCD_FMON_PRISM | * | X | PRISM status events (the PRISM adapter reads it through its own DAO; the row keeps the approval list complete and covers a generic source on the table) |

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
| F_PRISMDLV | ZCL_CD_FMON_CHK_SLA | E | STAGE=PRISM_DELIVERED;LATE_SEVERITY=W |
| F_FILERCV | ZCL_CD_FMON_CHK_SLA | E | STAGE=FILE_RECEIVED;LATE_SEVERITY=W |
| F_PRFAIL | ZCL_CD_FMON_CHK_REJECT | E | OUTCOME=PRISM_FAILED |
| F_PRFILE | ZCL_CD_FMON_CHK_PRISM_FILE | W | GRACE_MIN=60 |

`F_PRFAIL` reuses the reject check: with `OUTCOME=PRISM_FAILED` it reports only `PRISM_FAILED` (the existing `F_REJECT` row is unchanged and does not report it, so nothing is doubled). `F_PRFILE` reports `PRISM_UNKNOWN_FILE` (outbound file only PRISM reported) and `PRISM_NOT_LOADED` (inbound file PRISM delivered, not received in SAP) after `GRACE_MIN` — longer than the 5-minute cycle, so PRISM being faster than SAP's next read is no finding. The instant PRISM unit runs only the SLA, reject and PRISM-file checks.

## ZCD_OPS_PARAM (FMON parameters)

| PARAM_NAME | Example | Meaning |
|---|---|---|
| FMON_LOOKBACK_DAYS | 1 | days read back from legacy tables / files evaluated |
| FMON_OPEN_DAYS | 30 | open or partially processed files kept under watch |
| FMON_DUP_DAYS | 7 | duplicate-file history |
| FMON_TIME_ZONE | ‹EST› | time zone of legacy date/time fields and calendar windows |
| FMON_FACTORY_CAL | ‹US› | factory calendar when ZCD_FMON_CAL has none |
| FMON_RETURNS_WEEKDAYS | ‹1,2,3,4,5› | weekdays that are ACH returns cycle days |
| FMON_NOC_SLA_DAYS | 6 | NACHA NOC limit in banking days |
| FMON_MAX_ROWS | 50000 | row cap per legacy read; a lot scan reaching it is `LOT_SCAN_TRUNCATED` and derives no lot outcome (audit A38) |
| FMON_PRISM_MAX_BYTES | 16384 | body limit of the PRISM status API (413 above) |
| FMON_PRISM_INSTANT | X | X = the instant PRISM unit saves findings and alerts; blank = registry only, findings and alerts from the 5-minute run |
| FMON_AGE_BASIS | A | NOC / returns age in working days: `A` counts from the first working day **after** receipt, `N` treats a receipt on a non-working day as received on the next working day (audit A41). If the factory calendar cannot convert the dates the age is unknown: no aging finding, warning 248 instead |

## Alerting

FMON calls the core router (`ZIF_CD_OPS_ALERT~DISPATCH`) once per run. Thresholds, recipients, channels, digest, throttling and quiet hours are rows of `ZCD_OPS_ALERT_RULE` (owned by core), e.g. payment engine area `FMON`, minimum severity `E`, group1 pattern `ACH_*`. FMON keeps no alert configuration of its own.

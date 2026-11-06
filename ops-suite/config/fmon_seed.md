# FMON — example customizing rows (EXAMPLES — CONFIRM BEFORE TRANSPORT)

> **First principle:** every row below is an example built from the job schedule wiki and the landscape facts; none of it has been checked against PS4.
> **Analogy:** a pre-filled order form — the layout is right, but every line has to be ticked by someone who knows the stock.

Legend: `‹SE11›` = field name of an existing custom table that is **not known** (structure unverified). Fill it from SE11 in Phase 0. The engine validates every name against the DDIC at runtime and refuses unknown names (messages 200–203), so a wrong guess fails loudly, never silently.

## ZCD_FMON_IFACE (interface definition)

| IFACE_ID | DIR | FILE_TYPE | SOURCE_SYS | TARGET_SYS | PAY_METHOD | LOB | BANK_KEY | NAME_PATTERN | MIN_BYTES | MAX_BYTES | ACK_EXPECTED | ACK_LEVEL | OWNER | ACTIVE |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| ACH_PNC_DISB_OUT | O | PAYMENT | * | PRISM | ACH | * | PNC | `‹confirm pattern›` | 1 | 0 | X | PAYMENT | ‹team› | X |
| WIRE_JPMC_OUT | O | PAYMENT | * | PRISM | WIRE | * | JPMC | `‹confirm pattern›` | 1 | 0 | X | PAYMENT | ‹team› | X |
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
| ACH_PNC_DISB_OUT | FORWARDED_TO_BANK | 60 | P | W | only if a source reports the forward |
| ACH_PNC_DISB_OUT | ACK_RECEIVED | 240 | G | E | ‹confirm with bank cut-off› |
| WIRE_JPMC_OUT | ACK_RECEIVED | 30 | G | E | master prompt: "wire ack within 30 minutes" |
| ACH_RET_PNC_IN | FULLY_PROCESSED | 480 | G | E | FP09 lot complete same day ‹confirm› |
| NOC_PNC_IN | FILE_LOADED | 60 | P | W | |

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

| SRC_ID | IFACE_ID | TABLE_NAME | FILE_KEY_FIELD | FILE_NAME_FIELD | DATE_FIELD | TIME_FIELD | TS_FIELD | STATUS_FIELD | COUNT_FIELD | AMOUNT_FIELD | SIZE_FIELD | DEFAULT_STAGE | ADAPTER_CLASS |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| REGUT | (blank: by pattern) | ZCDT_REGUT | ‹SE11› | ‹SE11› | ‹SE11› | ‹SE11› | | ‹SE11 or blank› | ‹SE11› | ‹SE11› | ‹SE11› | GENERATED_IN_SAP | (blank) |
| ACHACK | ACH_PNC_DISB_OUT | ZCD_ACH_ACK | ‹SE11› | ‹SE11› | ‹SE11› | ‹SE11› | | ‹SE11› | ‹SE11› | ‹SE11› | | | (blank) |
| WIREACK | WIRE_JPMC_OUT | ZCD_WIRE_ACK | ‹SE11› | ‹SE11› | ‹SE11› | ‹SE11› | | ‹SE11› | | ‹SE11› | | | (blank) |
| CHKHIST | CHECK_POSPAY_OUT | ZCD_CHECK_HIST | ‹SE11› | ‹SE11› | ‹SE11› | ‹SE11› | | ‹SE11› | | | | | (blank) |
| ACHRTRV | ACH_RET_PNC_IN | ZCD_ACH_RTRV_LOG | ‹SE11› | ‹SE11› | ‹SE11› | ‹SE11› | | ‹SE11› | ‹SE11› | | | | (blank) |
| STRPPOUT | STRIPE_PAYOUT_IN | ZCD_STRP_POUT_LOG | ‹SE11› | ‹SE11› | ‹SE11› | ‹SE11› | | ‹SE11› | ‹SE11› | ‹SE11› | | | (blank) |

`FILE_KEY_FIELD` must be **unique per file over time** and identical in every table of the same file (e.g. a run/file ID). If the only common value is a constant file name, the engine raises `FILE_REF_REUSED` instead of merging days.

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
| FMON_MAX_ROWS | 50000 | row cap per legacy read |

## Alerting

FMON calls the core router (`ZIF_CD_OPS_ALERT~DISPATCH`) once per run. Thresholds, recipients, channels, digest, throttling and quiet hours are rows of `ZCD_OPS_ALERT_RULE` (owned by core), e.g. module `FMON`, minimum severity `E`, group1 pattern `ACH_*`. FMON keeps no alert configuration of its own.

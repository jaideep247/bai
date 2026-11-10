# Alert context review (2026-11-10)

> **First principle:** an alert must arrive carrying everything needed to act on it - what happened, how much is affected, where to look - so that the receiver never has to search for the run.
> **Analogy:** a returned parcel with a slip naming the depot, the van and the reason, instead of just "undeliverable".

User decision 2026-11-10: "All emails should be templates which can be edited and enhanced in future with
additional information, flexible and configurable; review all alerts to have as much business context and
relevant information as possible." This page lists every alert the suite can send, the template it uses,
the business context it carried before and carries now, and the gaps left with the reason. Mechanism:
`ops-framework/docs/ALERT_TEMPLATES.md`; templates: `templates/`; rules: `config/alert_seed.md`.
Nothing has run in SAP: the findings below are from the code and the seed rows.

## 1. Method

1. Every alert route: the 11 seed rules of `config/alert_seed.md`, the prepared report sent with `SEND( )`
   (morning report) and every check code that can reach `ZCL_CA_OPS_ALERT_ROUTER=>DISPATCH` (the EBS, FMON and
   HCK engines dispatch all findings of a run; the payment outcome snapshot of area `CD_OPS` does not
   dispatch - its failures reach the router through the health check `A_INFLIGHT`).
2. For each check-code family: the fields the finding carries at finding time and whether a seed rule
   selects it (patterns are PCRE on the complete value, `ZCD_OPS_PATTERN_CHECK`).
3. Gaps fixed only where the data is already in the engine at finding time (no new database read in a
   hot path, no amounts unless the rule's `SHOW_AMOUNTS` applies).

## 2. What every alert e-mail carries now (all rules)

| | Before (2026-11-10 morning) | After |
|---|---|---|
| Wording / layout | Fixed in code (`ZCL_CA_OPS_ALERT_POLICY`) | SAP e-mail template per alert type (`templates/`), editable in DV1, transported; built-in layout with the same content as fallback (reason on the alert log row) |
| Subject | `[SYSID][AREA][sev] <n> finding(s) - rule <rule>`; single finding: rule + text | Impact first: `[SYSID][AREA][sev] <check or rule>: <n> finding(s)[, amount per currency]`; ACK: files, payments, amounts |
| Header | Run line, run / job / exceptions app | + area, rule, severity text, check code, findings total / **new / repeated / overdue** (stored exceptions of the run), held back above the limit, **earliest due date and owner**, run start / end in `ALERT_TIME_ZONE`, exceptions app link (`ALERT_EXC_APP_LINK`); each suite template adds the business heading, the impact and *what to do* |
| Findings table | Severity, rule, check, object key, reference, **amount (always)**, message | Severity, rule, check, object type + key, reference, **business date, company code, account (masked), payment method, count** (column shown when known), message, context lines; **amount only with `SHOW_AMOUNTS`** (default off - user decision: open for all alerts but the missing bank ACK); the check's free `DETAILS` only with `SHOW_AMOUNTS` (they may carry amounts) |
| Text body | Subject, reference, one line per finding | + every known key and the context fields per finding, labelled |
| Evidence | `ZCA_OPS_ALLOG`: status, subject | + `TEMPLATE_ID`, `RENDERER`, `RENDER_INFO` (fallback or appended table) |

## 3. Alert rules (recipients, template, context)

Priority and lists: `config/alert_seed.md`. "Context before -> after" names what is added on top of section 2.

| Alert (rule) | Selects | Recipients | Template | Context before -> after | Gaps left and why |
|---|---|---|---|---|---|
| `EBS_BLOCK` | CD_EBS, B | ZCD_PAYOPS, escalation ZCD_RTBLEAD after 3 | `ZCD_OPS_ALERT_EBS_BLOCK` | Line / statement key, BTC group, reference, signed amount -> **+ company code, account (house bank / account ID or masked number), business date (booking / statement date), payment method of the line** (`ZCL_CD_EBS_ENGINE=>ADD_CONTEXT`, from the package in memory) | Amount hidden by default (open decision); file-level parser findings (`EMPTY_FILE`, BAI2 structure) have no statement - no company code |
| `EBS_ERROR` | CD_EBS, E; amber run; abort | ZCD_PAYOPS | `ZCD_OPS_ALERT_EBS` | as `EBS_BLOCK` | Message texts of some rules contain amounts (R02 bounds, R12 code totals, S02 balances) - written by the rule, shown in the message column (open decision on amounts in texts, `Release_Readiness.md` §5) |
| `FMON_SLA` | CD_FMON, E; **pattern corrected** (`.*SLA.*` matched no check code) -> rule pattern `F_(SLA\|PRISM.*\|FILERCV)` | ZCD_PAYOPS | `ZCD_OPS_ALERT_FMON_SLA` | **Before: never sent** (dead pattern). After: file name, interface, file ID -> **+ business date, payment method, record count** (`ZCL_CD_FMON_UTIL=>NEW_FINDING`) | Corrected pattern is a proposal (seed row, confirm before transport); control total has no currency in the finding (`FMON_DEFAULT_CURRENCY` is read by the engine, not the check) - hidden anyway by default |
| `FMON_ACK` *(new, proposed)* | CD_FMON, E, `(NO_)?BANK_ACK(_LATE)?\|ACK_.*_MISMATCH` | ZCD_PAYOPS | `ZCD_OPS_ALERT_ACK` (also chosen by the section for any rule without template) | **Before: no seed rule selected the ACK codes** (the documented `FMON_ERR` did not exist) - the ACK table was only built if some rule matched. After: routed; ACK table (house bank, bank, file, method, payments, amount, payment run, generated / delivered / ACK due, overdue by, totals per currency, unknown never 0) as block `TABLE_SECTION`; **`SHOW_AMOUNTS` = X** (user decision) | Rule is a proposal (confirm) |
| `FMON_FILE` *(new, proposed)* | CD_FMON, E, rule pattern `F_(MISSING\|REJECT\|DUP\|SIZE\|PRF.*)` without the regeneration codes | ZCD_PAYOPS | `ZCD_OPS_ALERT_FMON_FILE` | **Before: missing / rejected (NACK) / failed / duplicate / zero-byte / size / PRISM-failed files reached no rule** (only B via `ALL_ABORT`). After: routed; **+ business date (also of an expected file), payment method, record count** | Proposal (confirm recipients) |
| `FMON_PART` | CD_FMON, E; **pattern corrected** (`.*PARTIAL.*` matched no code) -> `LOT_.*` | ZCD_RETOPS | `ZCD_OPS_ALERT_RETURNS` | **Before: never sent.** After: lot findings with file context | Proposal (confirm that partial return lots are what the rule was meant for) |
| `FMON_BAIDL` | CD_FMON, E, `STAGE_DEADLINE_MISSED` | ZCD_PAYOPS, escalation after 6 | `ZCD_OPS_ALERT_DEADLINE` | Interface / day key, condition in GROUP2 -> **+ business date, missed stage as a context line** (`ZCL_CD_FMON_CHK_DEADLINE`) | Condition (GROUP2) is not a column: it is in the message text |
| `NOC_AGING` | CD_FMON, E, `NOC_AGING.*` | ZCD_COMPL | `ZCD_OPS_ALERT_NOC` | File key -> **+ business date, payment method, count** | `NOC_DUE_TODAY` (W) is not alerted - by design (morning report) |
| `FMON_REGEN` | CD_FMON, E/B; **pattern shortened** to `.*REGEN.*\|PRISM_DUP.*` (68 characters did not fit CHAR 35) | ZCD_PAYOPS, escalation after 2 | `ZCD_OPS_ALERT_REGEN` | File, earlier file (details) -> **+ business date, payment method, count**; earlier file visible with `SHOW_AMOUNTS` only (DETAILS) | Earlier file is in DETAILS (free text) - move to a context line when the regeneration check is next changed |
| `HCK_RED` | CD_HCK, E; red run; abort | ZCD_RTBSUP, escalation after 2 | `ZCD_OPS_ALERT_HCK` | Check / metric / dimension key, category and check in GROUP1/2, value vs threshold in the message -> **+ context line "Health check <id> (category, priority): <description>"** (message 839, `ZCL_CD_HCK_ENGINE=>FINALIZE_RESULT`); **payment requests not paid: business date = due date, count = requests** | Metric dimensions (`DIM1` / `DIM2`) are generic - company code / payment method only when a check uses them so (no mapping per check); amounts per currency of PRQ / in-flight are in DETAILS (shown only with `SHOW_AMOUNTS`) |
| `HCK_RECON` | CD_HCK, E; **pattern shortened** to `.*_BREAK` (56 characters did not fit) | ZCD_RTBSUP, escalation after 2 | `ZCD_OPS_ALERT_RECON` | Reconciliation set, sides and difference (details) -> **+ health check context line** | Sides and difference are amounts in DETAILS: shown only when the rule gets `SHOW_AMOUNTS` (open decision) - without it the receiver opens the set in the dashboard |
| `ALL_ABORT` | every area, B; abort | ZCD_RTBSUP | `ZCD_OPS_ALERT_ABORT` | Run, job, `RUN_ABORTED` with error class and trace -> **+ run start / end, what to do by error class** (template) | Trace is DETAILS (with `SHOW_AMOUNTS` only); the error class is in the message |
| `RUN_LOCKED` | every area, E | ZCD_RTBSUP | `ZCD_OPS_ALERT_LOCKED` | Area, variant, lock holder (message) -> + run keys | - |
| Morning report (`SEND`, route `HCK_MAIL_ROUTE`) | - | `ALERT_MORNING` | `ZCD_OPS_MORNING_REPORT` (`HCK_MAIL_TEMPLATE`) | Prepared HTML -> **in a template** (report = `TABLE_MAIN`, system / client / exceptions app around it) | Report content unchanged (`ZCL_CD_HCK_REPORT_HTML`) |

**14 alert types** (11 seed rules, 2 proposed rules, the morning report).

## 4. Check codes that can reach the router

All findings of an EBS, FMON and HCK run are dispatched; a code reaches an e-mail only if a rule selects it.

| Family (area, producer) | Codes | Routed by | Context at finding time (after) |
|---|---|---|---|
| EBS statement checks (CD_EBS, S01-S13, parsers) | `STMT_*`, `BALANCE_ARITHMETIC`, `OPENING_NE_PRIOR_CLOSING`, `GL_NE_CLOSING`, `ENTRY_COUNT`, `DECLARED_TOTALS`, `GROSS_TOTALS`, `ACCOUNT_*`, `BTC_COVERAGE`, `ENTRIES_NOT_ACCOUNTED`, `NOT_POSTED`, `POSTING_INCOMPLETE`, `BAI2_*`, `CAMT_*`, `EMPTY_FILE`, ... | `EBS_BLOCK` (B), `EBS_ERROR` (E) | statement key, reference, company code, account label, statement date |
| EBS line rules (CD_EBS, R01-R22) | `SIGN_MISMATCH`, `AMOUNT_*`, `CURRENCY_*`, `REF_*`, `REASON_*`, `PAYMENT_*`, `CHECK_*`, `RETRIEVAL_*`, `RETURN_*`, `DUPLICATE_*`, `VALUE_DATE_WINDOW`, `CODE_*`, `POSTING_RULE_*`, `GL_ACCOUNT_NOT_MAPPED`, `FI_DOC_*`, `LOOKUP_*`, `UNMAPPED_BTC`, `MAP_*`, ... | `EBS_BLOCK`, `EBS_ERROR` | line key, BTC, reference, company code, account label, booking date, payment method |
| EBS technical | `CIRCUIT_BREAKER`, `NO_DATA`, `PLUGIN_ERROR`, `RULE_*`, `KEY_LENGTH_CONFIG`, `ALERT_FAILED` | `ALL_ABORT` (abort), `EBS_ERROR` (E) | run, error class, trace (DETAILS) |
| FMON stage SLA (`F_PRISM`, `F_BANKACK`, `F_SLA`, `F_PRISMRCV`, `F_PRISMDLV`, `F_FILERCV`) | `NO_<stage>`, `<stage>_LATE`, `<stage>_INFERRED` (I), `PRISM_QUEUE_LONG` (W) | `FMON_SLA` (corrected), ACK stage: `FMON_ACK` | file, interface, file ID, business date, payment method, record count; ACK: section table |
| FMON ACK (`F_BANKACK`, `F_ACKMATCH`, deadline at ACK stage) | `NO_BANK_ACK`, `BANK_ACK_LATE`, `ACK_COUNT_MISMATCH`, `ACK_AMOUNT_MISMATCH` | `FMON_ACK` (new) | ACK evidence per file (section), amounts shown |
| FMON files (`F_MISSING`, `F_LATE`, `F_REJECT`, `F_DUP`, `F_SIZE`, `F_PRFAIL`, `F_PRFILE`) | `FILE_MISSING`, `UNEXPECTED_FILE`, `FILE_LATE` (W), `NACK`, `FILE_FAILED`, `DUPLICATE_FILE`, `ZERO_BYTE`, `SIZE_OUT_OF_BOUNDS`, `PRISM_FAILED`, `PRISM_UNKNOWN_FILE` (W), `PRISM_NOT_LOADED` (W) | `FMON_FILE` (new); W: morning report | file or interface / day, business date, payment method, record count |
| FMON lots / NOC | `LOT_UNPROCESSED`, `LOT_NOT_FOUND`, `LOT_SCAN_TRUNCATED`, `NOC_AGING`, `NOC_DUE_TODAY` | `FMON_PART` (corrected), `NOC_AGING` | file context |
| FMON deadline / regeneration | `STAGE_DEADLINE_MISSED`, `FILE_REGENERATED_NOT_FAILED`, `PRISM_DUPLICATE_NAME`, `REGENERATION_MISSING`, `FILE_REPLACED` (I) | `FMON_BAIDL`, `FMON_REGEN` | interface / day + business date + missed stage; file context |
| FMON technical | `UNMAPPED_FILE`, `UNMAPPED_STATUS`, `FILE_REF_REUSED`, `FILE_REF_AMBIGUOUS`, `PERSIST_CONFLICT`, `PERSIST_ERROR`, `MALFORMED_SOURCE_ROW`, `PLUGIN_ERROR`, `PATTERN_INVALID`, `ALERT_FAILED` | B only (`ALL_ABORT`); else the morning report | file / source, error class |
| HCK thresholds / jobs / technical / configuration / self-check | `THRESHOLD_*`, `BASELINE_*`, `JOB_*`, `STEP_*`, `TIMEOUT_OVERRUN`, `CONFIG_*`, `AGG_CONFIG_INVALID`, `MODULE_STALE`, `RUN_HUNG`, `CHECKS_NOT_CONFIGURED`, `CHECK_BUDGET_EXHAUSTED`, `PARAM_INVALID`, `POSTAREA_INVALID`, `SUPPRESSION_PATTERN_INVALID`, `PATTERN_INVALID`, `GL_TRANSFER_GAP`, `NR_*`, `QUEUE_*`, `TECH_READ_CAPPED`, `ALERT_FAILED`, `PLUGIN_ERROR` | `HCK_RED` (E / red run) | check, metric, dimension, value vs threshold (message), health check context line |
| HCK in-flight / payment outcome (`A_INFLIGHT`) | `PAYMENT_NOT_CLEARED`, `VALUE_DATE_MISSING`, `CLEARING_*`, `RETURN_INCONSISTENT`, `UNEXPECTED_SEQUENCE`, `PENDING_OUTCOME_MISSING`, `CHEQUE_*`, `BTC_ROLE_MISSING`, `MANUAL_CLEARING_REQUIRED`, `PAY_STATUS_LAG`, `PAY_SNAPSHOT_STALE`, `PAY_EVALUATED_LIVE`, `INFLIGHT_CONFIG`, `LIMITS_NOT_CONFIGURED` | `HCK_RED` | check context line; amounts in DETAILS (only with `SHOW_AMOUNTS`) |
| HCK payment requests (`A_PRQ_NOT_PAID`, `C_PRQ_*`) | `PRQ_NOT_PAID`, `PAY_NIGHTLY_MISSING` (W), cancellation / SPE codes | `HCK_RED` | **business date (due date), count (requests)**, source / stage, check context line |
| HCK reconciliation (`A_RECON_3WAY`) | `RECON_BREAK`, `RECON_SUBLEDGER_BREAK`, `STRIPE_GROUP_BREAK`, `RECON_TIMING` (I), `RECON_VARIANCE` (W), `RECON_NO_DATA`, `RECON_CONFIG` | `HCK_RECON` (`.*_BREAK`), `HCK_RED` | set, sides and difference (DETAILS), check context line |
| Framework run control (every area) | `RUN_LOCKED`, `RUN_ABORTED`, `ALERT_FAILED` | `RUN_LOCKED`, `ALL_ABORT`; `ALERT_FAILED` (W) morning report | run, job, error class |
| Payment outcome snapshot (CD_OPS) | `PAY_OUTCOME_*`, `PAY_SOURCE_AMBIGUOUS`, `PAY_STATUS_PENDING`, `PAY_BATCH_INCOMPLETE`, `PAY_EVIDENCE_FAILED` | not dispatched (stored; stale snapshot -> `PAY_SNAPSHOT_STALE` of `A_INFLIGHT`) | - |

## 5. Gaps fixed (code)

| Gap | Fix | Where |
|---|---|---|
| No template: wording fixed in code | Template per alert type, generic template, built-in fallback | framework `ZCL_CA_OPS_MAIL_*`, `templates/` |
| Amounts always in the findings table | Amounts only with `SHOW_AMOUNTS` (default off; on `FMON_ACK` only) | `ZCL_CA_OPS_ALERT_POLICY` |
| No new / repeated / overdue, due date, owner | From the stored exceptions of the run (one read by the run key) | `ZCL_CA_OPS_ALERT_DAO=>GET_EXCEPTION_FACTS` |
| EBS findings without company code, account, business date, payment method | Added from the package in memory | `ZCL_CD_EBS_ENGINE=>ADD_CONTEXT` |
| FMON file findings without business date, payment method, count | Added from the file registry row | `ZCL_CD_FMON_UTIL=>NEW_FINDING` / `NEW_KEY_FINDING`, `ZCL_CD_FMON_CHK_MISSING`, `_LATE`, `_DEADLINE` |
| HCK findings do not say which health check, category, priority | Context line (message 839) | `ZCL_CD_HCK_ENGINE=>FINALIZE_RESULT` |
| Payment requests not paid without due date / count fields | Business date = due date, count = requests | `ZCL_CD_HCK_C_PRQ_NOT_PAID` |
| ACK table bound to the policy's layout | Block `TABLE_SECTION` of template `ZCD_OPS_ALERT_ACK` (section names it) | `ZCL_CD_OPS_ACK_MAIL` |
| Morning report e-mail not editable | In template `ZCD_OPS_MORNING_REPORT` (`HCK_MAIL_TEMPLATE`) | `ZCL_CD_HCK_ENGINE` |
| ACK subject test expected the former area name `FMON` | Expects the area constant | `ZCL_CD_OPS_ACK_MAIL` test include |

## 6. Gaps fixed in configuration (proposed seed rows - confirm before transport)

`FMON_SLA` and `FMON_PART` patterns matched no check code; no rule selected the missing bank ACK codes or the
file failures; the `FMON_REGEN` and `HCK_RECON` patterns were longer than the pattern field (CHAR 35). The
corrected and new rows are in `config/alert_seed.md` (marked *proposed 2026-11-10*); they are configuration,
entered in DV1 on a customizing request after `ZCD_OPS_PATTERN_CHECK` confirms what they capture.

## 7. Gaps left

| Gap | Why left |
|---|---|
| Amounts in other alerts | Open user decision - configuration (`SHOW_AMOUNTS`), default off |
| Amounts inside finding texts (EBS R02 / R12 / S02, HCK outlier and threshold values) and in a single-finding subject | The text is written by the check (exceptions app and morning report use it too); changing it is a change of each check, after the decision on amounts |
| `AREA_TEXT` blank with data passed by code | ZCA_PARAM has no read API for the area description; the data source by key reads it (`ZI_CA_OPS_ALERTMAILCTX`) |
| HCK metric dimensions (`DIM1` / `DIM2`) not mapped to company code / payment method | The meaning of a dimension is per check configuration; a mapping would be new configuration |
| Regeneration: earlier file only in DETAILS | Move to a context line with the next change of the regeneration check |
| File-level EBS parser findings without company code | No statement exists for them |
| `FMON_DEFAULT_CURRENCY` not on the file finding | Read by the engine for ACK evidence; amounts are hidden by default |
| Payment outcome snapshot (CD_OPS) not alerted | By design: its state is checked by `A_INFLIGHT` (`PAY_SNAPSHOT_STALE`) |
| Template content in SAP | Created in DV1 from `templates/`; the SMTG API and abapGit support are VERIFY items (framework V17-V25) |

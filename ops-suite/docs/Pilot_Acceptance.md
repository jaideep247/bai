# Pilot acceptance - the five open daily controls of the first customer (build R)

> **First principle:** a control is accepted when the check behind it is built, its only missing input is a named business fact, and one configuration change turns it on - never when a row is ticked without a reading behind it.
> **Analogy:** a new smoke detector installed and wired, with the battery in the box: the electrician has finished, the owner only has to say which room it guards and click the battery in.

Status 2026-11-16: answer to finding 5 of the product review of 2026-11-15
(`docs/review/2026-11-15_FICA_Production_Support_Product_Review.md`) and the row R of
`docs/release/RELEASE_1_PLAN.md` section 2a. **Nothing has run in SAP.** Every check below is built, unit-tested with
doubles and delivered **inactive**; what remains open is a business fact (who answers it is named) or an SE11 name.
No field of a customer table was guessed: names not confirmed in the repository are placeholders in angle quotes, and a
check that still reads one raises - its control shows *not evaluated*, never *healthy*.

Source of truth for the rows: `config/control_seed.md` (controls, proposals P2-P7), `config/control_checks.csv`,
`config/check_registry.csv`, `config/check_aggregates.csv`, `config/hck_seed.md`, `config/fmon_seed.md`,
`config/param_definitions.csv`. VERIFY items: `docs/VERIFY_Suite.md` §7 (V240-V258).

## 1. What every new finding carries (all five controls)

| Evidence | Where it is on the finding |
|---|---|
| Count | `ITEM_COUNT` (1 per item finding; the number of items on the exposure finding) |
| Amount and currency | `AMOUNT` / `CURRENCY` per item; one information finding `EXPOSURE_PER_CURRENCY` per currency (count, sum, oldest item) - currencies are never added up; an item without amount (no register row, currency not configured) sits under a blank currency |
| Oldest age | context line *Age* of each item (days; hours for the collections checks); the exposure finding names the oldest item and its age |
| Deadline | context line *Deadline* and `BUSINESS_DATE` of the exposure finding (pending date + red days, the review day, the request's change + red hours, the due date and time of a file) |
| Owner | the control of the daily review named on every finding (context line *Control*); its owner, backup and team are the register row of `ZCA_OPS_CONTROL`, filled by the support lead in DV1 |
| Evidence keys | `OBJECT_KEY` (cheque number, payment document, request key, `<interface>/<due date>`), `REFERENCE` (payment document, run, request, file) and the context line *Evidence* |
| Not evaluated | a source, value, calendar or deadline row that is blank or still a placeholder raises (HCK: `PLUGIN_ERROR`, check status FAILED; framework runner: `CHECK_FAILED`; FMON: `DUE_FILE_NOT_EVALUATED`, E). Each is a finding under the control's check, so the control is never green without a reading. A read that reaches its cap is partial (`READ_CAPPED`) and keeps earlier exceptions open |

## 2. ECT pending items (`ECT_PENDING`, proposal P3)

| | |
|---|---|
| **Built** | Check `C_ECT_PENDING` (class `ZCL_CD_HCK_C_ECT_PENDING`, morning report, category C): COUNT (`ECT_PENDING`) and AGE (`ECT_PENDING_AGE`, oldest, days) of the cheques whose latest valid status in the cheque history `ZCD_CHECK_HIST` (rows with `STATE` = space only - confirmed) is a pending `ZECT_STATUS` value **and** that are still open on the cheque register (`DFKKCR`: `BNKDT` initial, `STATE` blank - reference system facts). Latest status = last row by date and time, so one row per cheque and one row per status change both work. Evidence per cheque: cheque number, payment document (`DFKKCR-DOC1R`), company code, amount, currency, age, deadline; a pending cheque without register row is reported with its own code. Covered-check row `CD_HCK` / `GROUP2` = `C_ECT_PENDING` |
| **Open fact** | (1) which `ZECT_STATUS` values mean *pending* (sent to IRIS and not yet mailed? status 1?) - **business: payment operations (disbursements) with the IRIS / PRISM owner**; (2) SE11 of `ZCD_CHECK_HIST`: cheque number, status, date and time field names - **SE11, payment engine developer**; (3) amber / red limits (count, days) - **business: control owner** (V240-V242) |
| **Activation step** | One customizing transport: `ZCD_HCK_DEF` row `C_ECT_PENDING` with PARAM1 names and PARAM2 `PENDING=` filled and ACTIVE = X, its two threshold rows, and the control `ECT_PENDING` ACTIVE = X with owner and team |
| **QA1 test** | ECT-1: one cheque per state in `ZCD_CHECK_HIST` - pending since 10 days with open register row; pending then mailed; pending but `DFKKCR-BNKDT` filled; pending only on a row with `STATE` set; pending without register row. **Expected:** one `ECT_CHEQUE_PENDING` (age 10, payment document, amount and currency of the register row), one `ECT_PENDING_NO_REGISTER`, one exposure finding per currency, metric `ECT_PENDING` = 2; nothing for the other three. ECT-2: PARAM2 with the placeholder left in - **expected:** `PLUGIN_ERROR`, check status FAILED, control *not evaluated* |

## 3. BlackLine extracts (`BLACKLINE`, proposal P4)

| | |
|---|---|
| **Built** | FMON outbound interfaces `BLACKLINE_COLL_OUT` (program `ZCD_FI_BLACKLINE_EXTRACT_COLL`) and `BLACKLINE_DISB_OUT` (program `ZCD_BLACKLINE_RECON`), each with a DEADLINE row of `ZCD_FMON_SLA` (stage `GENERATED_IN_SAP`, day type `*`), and the check row `F_BLKLINE` of the new FMON check `ZCL_CD_FMON_CHK_DUE_FILE` (`WHEN=BUSDAY;BUSDAY=2`): on the 2nd working day of the month by the factory calendar, after the due time + 60 minutes, **missing** (no extract of the month), **late** (first seen after the due time) or **empty when expected** (0 bytes) per interface; an inactive interface, a missing DEADLINE row or an unreadable calendar is *not evaluated* (E). `A_GL_TRANSFER` stays covered. Covered-check row `CD_HCK` / `BLACKLINE` → `CD_FMON` / `RULE_ID` = `F_BLKLINE`; once both are active the control is no longer *partial* |
| **Open fact** | (1) how the two extract files are evidenced (PRISM status event with an interface ID / file name, or a log table of the programs) and their file name patterns - **payment engine developer with the BlackLine interface owner**; (2) the due time on the 2nd business day and the factory calendar ID - **business: GL / reconciliation team**; (3) can an extract legitimately be empty (no postings in the month) - **business: GL / reconciliation team** (V247-V249) |
| **Activation step** | One customizing transport: the two `ZCD_FMON_IFACE` rows (pattern, owner, ACTIVE = X), the evidence source (an existing PRISM route or one `ZCD_FMON_SRC` row with its approval), the two DEADLINE rows (due time, ACTIVE = X), check row `F_BLKLINE` (`CAL=` filled, ACTIVE = X), `FMON_LOOKBACK_DAYS` ≥ 5 |
| **QA1 test** | BL-1: on the 2nd business day of a QA1 month, generate only the collections extract before the due time and an empty disbursements extract after it. **Expected:** no finding for `BLACKLINE_COLL_OUT`; `DUE_FILE_EMPTY` and `DUE_FILE_LATE` for `BLACKLINE_DISB_OUT`. BL-2: no extract at all - **expected** `DUE_FILE_MISSING` for both after due time + 60 minutes, none before, none on the 1st or 3rd business day. BL-3: remove the DEADLINE row - **expected** `DUE_FILE_NOT_EVALUATED`. The exceptions are closed by the operator once the file is in (they are outside the reconciliation scope of the 5-minute run) |

## 4. Base-rejected items (`BASE_REJECTS`, proposal P2)

| | |
|---|---|
| **Built** | The scaffolded checks of process `CD_COLL` / `BASE_REQ_LIFE` are complete (meaning confirmed 2026-11-10: a collections request the source BASE rejected after SAP sent `SCHEDULED`; a Stripe card premium was already collected, so every reject must end in a successful Stripe refund called by SAP). `COLL_R2_SCHEDULED` (`ZCL_CD_COLL_C_NO_ANSWER`): latest status `SCHEDULED` without an answer of the source after the amber / red hours. `COLL_R3_REFUND` (`ZCL_CD_COLL_C_REFUND`, the main check): latest status = the reject value, matched with SAP's refund log in one set read - a successful refund closes it, only a failed refund is `PREMIUM_REFUND_FAILED` (E) at once, no successful refund after the limits is `PREMIUM_REFUND_MISSING` (W / E). Shared rules `ZCL_CD_COLL_RULES`; reads through the DDIC-validated, approved configured-source reader of the payment trace. `COLL_R1_PENDING` / `COLL_R4_SRCPOSTED` stay no-code aggregate rows. The data source stays a placeholder: parameters `COLL_SRC_REQUEST`, `COLL_SRC_REFUND`, `COLL_REJECT_VALUE`, `COLL_REFUND_OK`, `COLL_REFUND_FAILED`, `COLL_R2_AMBER_H` / `_RED_H`, `COLL_R3_AMBER_H` / `_RED_H`, `COLL_CURRENCY` (area CD_OPS, delivered blank) and the aggregate rows R1 / R4 |
| **Open fact** | Questions 1-6 of `config/control_seed.md` §2a: the request status table, its fields (request key, company code, status, date / time of the change, amount) and the reject value; where the source's answer is logged; the refund log (key back to the request, status, success and failure values); hours for R2 and R3; the currency - **SE11: payment engine developer; business: collections operations team** (V250-V253) |
| **Activation step** | One customizing request: the COLL_ parameter values, the placeholders of the R1 / R4 aggregate rows and the approved table rows replaced, the four `ZCA_OPS_CHECK` rows, process and control `BASE_REJECTS` ACTIVE = X, area `CD_COLL` with role `Z_CD_OPS_COLL` and the SO23 list of rule `COLL_LIFE`, job `ZCA_OPS_CHECK_RUN` (`CD_COLL`, `DAILY`). No code change |
| **QA1 test** | BR-1: four requests - rejected with a successful refund after a failed attempt; rejected with a failed refund only; rejected without refund for longer than the red hours; `SCHEDULED` past the red hours. **Expected:** nothing for the first, `PREMIUM_REFUND_FAILED` (E), `PREMIUM_REFUND_MISSING` (E), `REQ_NO_SOURCE_ANSWER` (E), each with company code, amount and request key, exposure findings per currency. BR-2: `COLL_REJECT_VALUE` blank - **expected** `CHECK_FAILED` for `COLL_R3_REFUND`, control *not evaluated* |

## 5. Missing check IDs (`MISSING_CHECK_IDS`, proposal P6)

| | |
|---|---|
| **Built** | Check `C_CHQ_NO_ID` (class `ZCL_CD_HCK_C_CHQ_NO_ID`, data access `ZCL_CD_HCK_CHEQUE_DAO`): the cheque payments of the runs of the day before the report date - `DPAYH` without proposal run, `DOC1R` filled, `RZAWE` a cheque method - without a `DFKKCR` row of the same payment document and run date that carries a cheque number (one anti-join; fields seen on the reference system; its test tool treats a run payment without `DFKKCR` row as an error). One error per payment with run, company code, method, house bank, amount, currency, deadline = the review day; exposure per currency; metric `CHEQUE_NO_ID`. Covered-check row `CD_HCK` / `GROUP2` = `C_CHQ_NO_ID` |
| **Open fact** | (1) that a *missing check ID* is a cheque payment without a cheque number on the register (and not a health check that did not run) - **business: disbursements support lead**; (2) the cheque payment methods (`RZAWE` values; the CHQ class of posting area ZPMC is the likely list) - **FI-CA configuration owner**; (3) from when it is missing - the print run on the run day, so the runs of the day before (`OFFSET=1`) - **business: disbursements support lead** (V243-V246) |
| **Activation step** | One customizing transport: `ZCD_HCK_DEF` row `C_CHQ_NO_ID` with `METHODS=` filled and ACTIVE = X (threshold row delivered: 1 / 1), control `MISSING_CHECK_IDS` ACTIVE = X with owner and team |
| **QA1 test** | MC-1: a cheque payment run in QA1 with one payment whose cheque was not created (no `DFKKCR` row), one with a cheque, one proposal run and one ACH payment. **Expected next morning:** one `CHEQUE_NUMBER_MISSING` (E) for that payment document with amount and currency, metric 1, one exposure finding; nothing for the others. PlanViz of the anti-join on the busiest run day (V246) |

## 6. Returns notification to the source (`RETURNS_NOTIF`, proposal P7)

| | |
|---|---|
| **Built** | `F_LOT` and `F_NOCAGE` stay. Chosen route - the one with fewer open facts: **an FMON outbound interface with a deadline** (configuration only, no customer field): interface `RETURNS_NOTIF_OUT` with a DEADLINE row and the check row `F_RETNOTIF` of `ZCL_CD_FMON_CHK_DUE_FILE` (`WHEN=RETURNS`): on a business day with a returns file, the notification must be generated by its due time - missing, late, empty or *not evaluated* as in §3. The request-log route would need the request log's FIN-number and time fields, the value meaning *source notified of the return* and the link from the returns lot item to the request - four unconfirmed names instead of two. Covered-check row `CD_FMON` / `RETURNS_NOTIF` → `RULE_ID` = `F_RETNOTIF` |
| **Open fact** | (1) **how the source (PCLM, DIS) is told about a return or NOC**: an outbound file; or the payment status update runs to the source (mass activity, variants `PSU_PCLM`, `PSU_DIS` seen in the reference system's test tool) - **do these runs report returns?**; or a status row of the request log - **business: payment operations with the PCLM interface owner**; (2) for a file: name pattern, evidence source, due time; for the PSU runs: the job names and window - **payment engine developer** (V254-V255) |
| **Activation step** | File: one customizing transport - interface row (pattern, target, ACTIVE = X), evidence source, DEADLINE row, check row `F_RETNOTIF` ACTIVE = X. PSU runs: instead a job-cycle step for the PSU job after the returns lot (`ZCD_JOB_CYCLE` / `ZCD_JOB_STEP`, the `B_CYCLE_*` checks) and a covered-check row `CD_HCK` / `GROUP2` = that cycle check; `F_RETNOTIF` stays inactive |
| **QA1 test** | RN-1 (file answer): a returns file loaded on a QA1 business day, no notification by the due time + 60 minutes - **expected** `DUE_FILE_MISSING` for `RETURNS_NOTIF_OUT` on that day, none on a day without returns file; RN-2: notification generated after the due time - **expected** `DUE_FILE_LATE` (W). RN-3 (PSU answer): PSU step cancelled - **expected** the cycle check red for the step |

## 7. Order and sign-off

1. Answers V240-V255 recorded in the release pack (`Release_Readiness.md`), names replaced in the seed files above by
   transport from DV1 - one customizing request per control.
2. ABAP Unit in DV1 (V256): `ltc_ect_pending`, `ltc_chq_no_id`, `ltc_cheque_dao`, `ltc_exposure`, `ltc_due_file`, both
   `ltc_check` classes of the collections checks.
3. QA1 tests of §2-§6 in the pilot window (`docs/QA1_Pilot.md`); each control activated only after its test passed.
4. The control's owner signs off its first daily review with the evidence of the test.

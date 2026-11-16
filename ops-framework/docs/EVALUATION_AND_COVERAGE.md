# Evaluation state, alert delivery and monitor coverage

> **First principle:** a control is only green when the product knows it looked. Every check run therefore says what
> it was supposed to look at, how fresh its sources were, whether it looked at all of it, and what it concluded -
> and "could not look" is a state of its own, never "nothing found". The same holds for alerts (submitted is not
> delivered) and for monitors (a monitor that did not run is a gap, not silence).
> **Analogy:** a night-watch round. The guard does not write "all quiet" for a floor he could not enter; he writes
> "floor 3 locked, not checked". The supervisor does not sign the round off as quiet while a floor is unchecked
> unless he says why. A radio call that was sent is not a call that was heard. And a guard who never started his
> round is missing from the sheet - the sheet shows the empty line.

Build O of Release 1 (`docs/release/RELEASE_1_PLAN.md` section 2a, row O; review 2026-11-15 finding 3, section 4
"Model control completion", P1 "Reconcile monitor coverage and alert delivery", distribution row "monitor-coverage
state", catalogue row "separate milestones"). Framework-wide and generic: every registered check of every area,
existing ones unchanged. Status 2026-11-16: built and lint-clean (abaplint, 7.58 syntax), offline fixtures green;
**not activated, ABAP Unit not executed** (`docs/VERIFY.md` V270-V289).

## 1. One evaluation state for every control

For every registered check and every run the runner `ZCL_CA_OPS_CHECK_RUNNER` stores one **evaluation record**
(`ZCA_OPS_EVAL`, sources `ZCA_OPS_EVALSRC`; rules `ZCL_CA_OPS_EVAL`, repository `ZIF_CA_OPS_EVAL_DAO`) in the run's
unit of work - never in test mode - also for a check that was **not run** (licence refused, business process not
in effect):

| Item | Field | Meaning |
|---|---|---|
| Expected scope | `AREA`, `BUS_DATE`, `PERIOD`, `BUKRS_LIST` | what was supposed to be evaluated: the area, the business date (the check's own, else the run date), the accounting period (the check's own, else the month of the business date) and the company codes (blank = the area) |
| Expected / observed | `EXPECTED_CNT`, `OBSERVED_CNT` | when the check counts them (files expected per day, alerts submitted, checks expected to run) |
| Source freshness | `FRESH_AT`, `FRESH_SOURCE`; per source `ZCA_OPS_EVALSRC` (`NEWEST_AT`, `STALE_MIN`, `IS_STALE`) | the newest observation of every source the check names; the record keeps the oldest of them and its source. A source older than its limit (its own, else `EVAL_SOURCE_STALE_MIN`) is stale |
| Watermark | `WATERMARK` | how far the check's sources were read (payment file lifecycle: the newest day watermark) |
| Completeness | `COMPLETENESS` | `C` complete, `P` partial, `N` not evaluated (the flags of the payment file day register) |
| Result class | `RESULT_CLASS` | `OK`, `ZERO_OK`, `HOLIDAY`, `PER_CLOSED`, `STALE`, `NOT_EVAL`, `FINDINGS` |
| Display state | `EVAL_STATE` | the one state support sees (section 3) |
| Reason | `REASON_CODE`, `REASON` | why it is not complete, stale or in a closed period (messages 560-566) |
| Last valid result | `LAST_VALID_RUN`, `LAST_VALID_AT`, `LAST_VALID_CLS` | the latest run of the check that was complete (the record itself when it is) |
| Licence | `LIC_STATE`, `LIC_MODULE` | blank covered, `W` ran under a licence warning, `R` refused - read through the existing licence service at the run |

### 1.1 One vocabulary - builds K and N mapped onto it

Stored codes are at most 10 characters (domain fixed values, texts from DD07L / DD07T): `NOT_EVAL` is the code of
build K's day register, not a third spelling; `PER_CLOSED` is "period closed". `ZCL_CA_OPS_EVAL=>OF_TERM` maps:

| Term | From | Result class | Counts as |
|---|---|---|---|
| `OK` | K day | `OK` | evaluated |
| `ZERO_OK` | K day | `ZERO_OK` | evaluated |
| `HOLIDAY` | K day | `HOLIDAY` | evaluated |
| `STALE` | K day, N evaluation (`PAYRUN_MISSING`, `EBS_SOURCE_STALE`) | `STALE` | evaluated |
| `NOT_EVAL` | K day (failed read) | - | not evaluated |
| `MISSING`, `PARTIAL` | K day (fewer files than expected - a business finding, not a partial evaluation) | `FINDINGS` | evaluated |
| `PENDING` | K day (deadline not passed) | - | nothing (no verdict yet) |
| `OBSERVED` | N evaluation | `FINDINGS` with an owned exception, else `OK` | evaluated |
| `ZERO_VOLUME` | N (`CASH_ZERO_VOLUME`) | `ZERO_OK` | evaluated |
| `NOT_EXPECTED` | N (`CASH_NOT_EXPECTED`) | `HOLIDAY` | evaluated |
| `NOT_EVALUATED` | N (`CASH_NOT_EVALUATED`) | - | not evaluated |

The payment file check folds every day result and every failed source (`ZCL_CA_OPS_CHK_PAYFILE`); the cash checks
fold the evaluation of every exception in their context (`ZCL_CA_OPS_CASH_CTX=>FINDING`, returned by `EVAL( )`).
The worse class wins (rank OK < ZERO_OK < HOLIDAY < PER_CLOSED < FINDINGS < STALE < NOT_EVAL); evaluated and not
evaluated terms together make the record partial, only not-evaluated ones make it not evaluated.

### 1.2 Checks that report nothing new

`ZIF_CA_OPS_CHK_TYPES=>TY_RESULT` has a new **optional** component `EVAL` (`ZIF_CA_OPS_EVAL_TYPES=>TY_CHECK_EVAL`):
every existing check class compiles unchanged and gets the defaults of its result:

| What the check returned | Completeness | Result class |
|---|---|---|
| it raised (the runner's `CHECK_FAILED`) | `N` | `NOT_EVAL` (reason 560 with the error) |
| `PARTIAL` = X | `P` | `FINDINGS` with an owned exception (B / E / W), else `OK` - shown `PARTIAL` |
| no owned exception | `C` | `OK` |
| owned exceptions | `C` | `FINDINGS` |

A check that fills `EVAL` may set the class, the completeness, the reason, the scope, the counts, the watermark and
its sources (`ZCL_CA_OPS_EVAL=>MERGE_TERM` / `ADD_SOURCE`). The runner then still applies three rules: an error
(B / E) never hides behind a zero, a holiday or a closed period (class `FINDINGS`); the zero or OK of a **stale
source** is `STALE`; the zero or OK of a **closed period** is `PER_CLOSED`.

**Missing DDIC objects (2026-11-16, build Q).** A check that reads a table, view or field the system does not have
says so in `EVAL` instead of failing: the aggregate check counts its measured and unmeasured rows (`EVALUATED` /
`UNEVALUATED`; an unmeasured row on a missing table or field gives the reason code `DDIC_MISSING`, message 636), the
link registry check counts the objects whose source or fields are missing (633). Some missing = `P` (partial), all
missing = `N` (not evaluated) - never `OK`, never a dump (`docs/EXTENSION_AND_GATE_PROOF.md` section 6).

### 1.3 Closed accounting period

Configurable per area through the period-close calendar `ZIF_CA_OPS_EVAL_PERIOD`: the delivered
`ZCL_CA_OPS_EVAL_PERIOD` reads `EVAL_PERIOD_CLOSED` (comma list `AREA:YYYYMM` - the area and all its company codes -
or `AREA:BUKRS:YYYYMM` - one company code; `*` = every area); a scope with company codes is closed when each of them
is. A site with its own period-close calendar names its class in `EVAL_PERIOD_SOURCE`. The product does not read
SAP's posting period tables (V275). A check of a closed period without findings is `PER_CLOSED`, not `OK`: no
activity is expected, so a zero proves nothing about health; findings stay findings.

## 2. Different conclusions for different situations

| Situation | Record | Support reads |
|---|---|---|
| Everything expected was read and nothing is wrong | `C` / `OK` | green |
| A valid day without volume (job finished, nothing to pay) | `C` / `ZERO_OK` | green, "valid zero volume" |
| Holiday or weekend of the business calendar | `C` / `HOLIDAY` | green, "not expected" |
| Accounting period closed | `C` / `PER_CLOSED` | neutral, "period closed" - not counted as healthy |
| A source silent past its limit (delayed feed) | `STALE` | red, with the source and its last observation |
| Part of the scope could not be read | `P` | amber `PARTIAL`, earlier exceptions stay open |
| The query failed / the check raised / not run | `N` / `NOT_EVAL` | red, with the reason |
| Exceptions raised | `FINDINGS` | the exceptions themselves |

## 3. Never green when unknown

- **Area dashboard** `ZR_CA_OpsCheckStatus` / `ZC_CA_OpsCheckStatus` (service `ZUI_CA_OPS_DASH`): column
  *Evaluation* with its text and criticality - `NOT_EVAL` and `STALE` red, `PARTIAL` and `FINDINGS` amber,
  `PER_CLOSED` neutral, `OK` / `ZERO_OK` / `HOLIDAY` green - from `ZI_CA_OpsEvalNow`: no record = `NOT_EVAL`, a
  record older than the area's schedule window (`CHECK_STALE_MIN_<area>`, else `CHECK_STALE_MIN_DEFAULT`) = `STALE`.
  Facet *Evaluation*: completeness, result, reason, scope, expected / observed, source freshness, watermark, last
  valid result. `IsAttention` also for an unknown evaluation; variant *Not evaluated, stale or partial*.
- **Overview card counters**: `UnknownCount` (data point `ChecksUnknown`), `NotEvaluatedCount`, `PartialCount` next to
  the existing `CheckCount`, `StaleCount`, `FlaggedCount`.
- **Daily control review** `ZR_CA_OpsCtlReview` (service `ZUI_CA_OPS_REV`): per control and business date the
  covered checks (`GROUP2` rows), of them those whose latest evaluation of the date is unknown or missing
  (`ZI_CA_OpsCtlEval`), the state `OK` / `PARTIAL` / `NOT_EVAL` with its criticality, variant *Checks not evaluated*,
  counter `UnknownCount`. **A control with unknown covered checks is never signed off as healthy without an
  observation** (`ZCL_CA_OPS_REVIEW_POLICY=>CAN_REVIEW`, message 567) - the observation is the reviewer's reason.

## 4. Alert delivery confirmed separately from submission

`ZCA_OPS_ALLOG-STATUS` S means *submitted* (the channel accepted the alert). Delivery is recorded apart:
`DLV_STATE` (`P` pending, `D` delivered, `F` failed after submission, `N` the channel cannot confirm; blank = not
asked yet), `DLV_REF`, `DLV_CHECKED_AT`, `DLV_AT`, `DLV_INFO`.

| Channel | How it confirms | Delivered when |
|---|---|---|
| Application log (`ZCL_CA_OPS_CHN_APPLOG`) | delivered on write: `BAL_DB_SAVE` succeeded | at submission (`D`); a partly written log is `F`; reference = SLG1 external ID |
| E-mail (`ZCL_CA_OPS_CHN_EMAIL`) | the send status reader of `EVAL_EMAIL_READER` (`ZIF_CA_OPS_DLV_READER`) - the SAPconnect status (SOST) of the send request | the reader says so. **No reader is delivered**: the BCS / SOST status read is not verified (V271, V272), so without one the e-mail answers `N` - BCS acceptance is never delivery |
| A customer's channel | the optional method `ZIF_CA_OPS_ALERT_CHANNEL=>CONFIRM` (and `DELIVERY_REF`), `DEFAULT IGNORE` | its own answer; a channel that does not implement it is `N` |

- At submission the router stores the channel's reference and its first answer (`ZCL_CA_OPS_ALERT_ROUTER`).
- The **confirmation step** `ZCL_CA_OPS_ALERT_CONFIRM` (report `ZCA_OPS_ALERT_CONFIRM`, every 15 minutes) asks the
  channel of every undecided alert of the last `EVAL_DLV_LOOKBACK_H` hours again and stores the answer; then it runs
  the checks of area `CA_OPS` in group `ALERTDLV`. A channel that fails or is no longer configured leaves the alert
  pending / `N` - never delivered. Nothing is sent again.
- The **delivery check** `ZCL_CA_OPS_CHK_ALERT_DLV` (registry row `CA_OPS / ALERT_DELIVERY`) raises
  `ALERT_NOT_CONFIRMED` (W) for an alert not confirmed `EVAL_DLV_CONFIRM_MIN` minutes after its submission,
  `ALERT_DLV_FAILED` (E) for a failure after submission, and one `ALERT_DLV_UNCONFIRMABLE` notice per channel that
  cannot confirm (severity `EVAL_DLV_UNCONFIRMABLE`, I by default). Its source is the confirmation step itself: when
  the step stops running, its evaluation becomes `STALE`.
- **Reconciliation** `ZR_CA_OpsAlertRecon` / `ZC_CA_OpsAlertRecon` (service `ZUI_CA_OPS_DASH`, runs of the last 7
  days): findings that should have alerted (owned exceptions of the run) versus alerts submitted versus alerts
  delivered, with the decisions in between (held back on purpose, failed at submission, claimed) and the state
  `FAILED`, `PENDING`, `UNCONFIRM`, `NOT_ROUTED` (exceptions, no routing decision), `DELIVERED`, `NONE`.

## 5. Monitor coverage

A customer sees a monitor gap, never silence. Per registered check (active or not), area and licence module
(`ZCA_OPS_LICMOD`: the check class's module, else the catalogue process's, else `CORE`):

| State | When | Card |
|---|---|---|
| `DISABLED` | the registry row is inactive, or its business process is not in effect (catalogue activation) | neutral |
| `REFUSED` | the licence refuses a module it needs (`LIC_ENFORCE` = X, module not licensed) | red, gap |
| `NOT_RUN` | expected, but no evaluation within its schedule window | red, gap |
| `IMPAIRED` | its latest evaluation is `NOT_EVAL`, `STALE` or `PARTIAL` | amber, gap |
| `WARNED` | it runs under a licence warning (`LIC_ENFORCE` = W, module not covered) | amber |
| `RAN` | evaluated within its window | green |

- **View** `ZR_CA_OpsCoverage` / `ZC_CA_OpsCoverage` (service `ZUI_CA_OPS_DASH`): one row per check, counters
  `ExpectedCount`, `RanCount`, `ImpairedCount`, `NotRunCount`, `DisabledCount`, `RefusedCount`, `WarnedCount`,
  `GapCount` for a card per area and module; the licence state is the one the runner recorded at the run.
- **Check** `ZCL_CA_OPS_CHK_COVERAGE` (registry row `CA_OPS / COVERAGE`, group `MORNING`): the same rule
  (`ZCL_CA_OPS_COVERAGE`) with the licence read **live through the existing licence service** (`ZIF_CA_OPS_LICENSE`:
  `MODULES_OF_CHECK`, `DECIDE` - no other verification); `MONITOR_NOT_RUN` and `MONITOR_REFUSED` = E,
  `MONITOR_IMPAIRED` and `MONITOR_LIC_WARNED` = W, so the existing alert rules route a gap.

## 6. Catalogue milestones

Four states per catalogue process, tracked apart and never collapsed into "active" (`ZR_CA_OpsCatalogue`, list
*Process catalogue*, facet *Milestones*; generated catalogue document `docs/catalogue/catalogue.md`):

| Milestone | Source |
|---|---|
| Catalogue entry | the process row (`ZCA_OPS_CATPRC`) |
| Runnable check | a registered check with a class of a business process that monitors it (`ZI_CA_OpsCatRun`; in the document: a monitor with a class or aggregate rows in the package spec) |
| Platform-validated | `ZCA_OPS_CATVAL`: date, system and release as recorded by the install harness or an operator (report `ZCA_OPS_CAT_VALIDATE`, source H / O) - **never seeded**, blank in the delivery |
| Customer-activated | the effective activation (`ZI_CA_OpsCatProcEff`) |

An activated process without a runnable or validated check is red; variant *Activated, not platform-validated*.

## 7. Objects, parameters, messages

| Object | Role |
|---|---|
| `ZIF_CA_OPS_EVAL_TYPES` | vocabulary, record, delivery, coverage, parameters `EVAL_*`, messages 560-599 |
| `ZCL_CA_OPS_EVAL` | rules of the record (mapping, defaults, precedence, stale source, closed period, display state) |
| `ZIF_CA_OPS_EVAL_DAO` / `ZCL_CA_OPS_EVAL_DAO` | records and their last valid result (factory `GET_EVAL_DAO`, injector `INJECT_EVAL_DAO`) |
| `ZIF_CA_OPS_EVAL_PERIOD` / `ZCL_CA_OPS_EVAL_PERIOD` | period-close calendar (factory `GET_EVAL_PERIOD`, injector `INJECT_EVAL_PERIOD`) |
| `ZCL_CA_OPS_COVERAGE`, `ZCL_CA_OPS_CHK_COVERAGE` | coverage rule and check |
| `ZIF_CA_OPS_DLV_READER`, `ZCL_CA_OPS_ALERT_CONFIRM`, `ZCL_CA_OPS_CHK_ALERT_DLV`, `ZCA_OPS_ALERT_CONFIRM` | e-mail status reader contract, confirmation step, delivery check, job |
| `ZCA_OPS_CAT_VALIDATE` | platform validation record |
| `ZCA_OPS_EVAL`, `ZCA_OPS_EVALSRC`, `ZCA_OPS_CATVAL`; `ZCA_OPS_ALLOG-DLV_*` | tables (delivery class A) |
| domains `ZCA_OPS_EVAL_STATE`, `ZCA_OPS_EVAL_CMPL`, `ZCA_OPS_COV_STATE`, `ZCA_OPS_DLV_STATE` | codes with texts (DD07L / DD07T; text views `ZI_CA_OpsEvalStateT`, `ZI_CA_OpsCovStateT`) |
| `ZI_CA_OpsEvalLastAt`, `ZI_CA_OpsEvalLast`, `ZI_CA_OpsEvalNow`, `ZI_CA_OpsEvalDay`, `ZI_CA_OpsCtlEval`, `ZR/ZC_CA_OpsCoverage`, `ZI_CA_OpsReconFind`, `ZI_CA_OpsReconAlert`, `ZR/ZC_CA_OpsAlertRecon`, `ZI_CA_OpsCatRun`, `ZI_CA_OpsCatVal`, `ZI_CA_OpsCatValLast` | CDS (read-only) |

Parameters (area `CA_OPS`, `docs/PARAMETERS.md`): `EVAL_SOURCE_STALE_MIN` (1500), `EVAL_PERIOD_CLOSED` (blank),
`EVAL_PERIOD_SOURCE` (blank), `EVAL_DLV_CONFIRM_MIN` (30), `EVAL_DLV_LOOKBACK_H` (48), `EVAL_EMAIL_READER` (blank),
`EVAL_DLV_UNCONFIRMABLE` (I). Retention: the records are deleted with their run (target `RUN`).

## 8. Proof offline

- ABAP Unit (doubles): `ZCL_CA_OPS_EVAL` (every result class, the defaults of a legacy check, `PER_CLOSED`, stale
  source, partial), `ZCL_CA_OPS_EVAL_PERIOD`, `ZCL_CA_OPS_EVAL_DAO` (OSQL), `ZCL_CA_OPS_CHECK_RUNNER` (a record per
  check, raised, closed period, not run), `ZCL_CA_OPS_REVIEW_POLICY` (sign-off blocked on unknown),
  `ZCL_CA_OPS_ALERT_CONFIRM` (confirmed / not confirmed / cannot confirm / not configured / failing / test mode),
  `ZCL_CA_OPS_CHN_EMAIL` and `ZCL_CA_OPS_CHN_APPLOG` (`CONFIRM`), `ZCL_CA_OPS_CHK_ALERT_DLV`, `ZCL_CA_OPS_COVERAGE`
  and `ZCL_CA_OPS_CHK_COVERAGE` (licensed / refused / warned / disabled / impaired / ran / not run).
- Fixture spec `config/evaluation/fixtures.json` and reference model `tools/abaptools/evaluation.py` (the rules of
  `ZCL_CA_OPS_EVAL` and `ZCL_CA_OPS_COVERAGE`); root test `tools/tests/test_evaluation.py` runs every scenario,
  checks the codes against `ZIF_CA_OPS_EVAL_TYPES` and that each scenario names an existing ABAP Unit method.

## 9. Limits and open items

- The e-mail channel cannot confirm until a send status reader is verified and plugged (V271, V272; decision D-O2).
- The delivered period-close calendar is a parameter list; SAP's posting periods are a site adapter after V275.
- The coverage view shows the licence state of the last run; the coverage check reads it live.
- The daily review counts covered checks by `GROUP2` rows only (rows by `RULE_ID` / `CHECK_CODE` name no check); a
  business date before the first evaluation record shows its covered checks as not run.
- An evaluation record is area-level: its company codes are its scope, its state is shown on the area-level slice.

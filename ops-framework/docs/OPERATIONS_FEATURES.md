# Operations response features (ZCA_OPS, 2026-11-11)

> **First principle:** the framework already knows what is wrong; these features make sure the right person learns it once, at the right time, with the first step in hand - and that the time it took is measured, not guessed.
> **Analogy:** a hospital ward - the monitors already beep (findings and alerts); now every alarm carries its care protocol (runbook), alarms during planned maintenance are silenced but recorded (downtime), an unanswered alarm goes to the senior nurse after a while (escalation), twenty alarms of one failing pump are one call (correlation), the ward reports its response times (metrics) and every shift hands over in one sheet (handover).

Status 2026-11-11: written and statically checked offline (abaplint 0 issues, house checks, tool tests); **nothing
activated, no ABAP Unit run** (`docs/VERIFY.md` V70-V79). Reusable by any consumer: every piece is configuration
of the consumer's areas (rows in `ZUI_CA_OPS_CFG`, parameters of area `CA_OPS`, downtime windows in the
downtime app); the framework never names a consumer. Install: `docs/INSTALL.md` §6b; parameters:
`docs/PARAMETERS.md`; authorisation: `docs/auth_zca_ops.md` §2 and §3a.

| # | Feature | Configuration / data | Where it shows | Code |
|---|---|---|---|---|
| 1 | Runbook link per check | `ZCA_OPS_RUNBOOK` (C) in `ZUI_CA_OPS_CFG` (*Runbook links per check*) | exceptions app (facet *Runbook*, link column), alert e-mail (`RUNBOOK_URL`, `FIRST_ACTION`), CDS `ZI_CA_OpsFindRunbook` for any app | `ZCL_CA_OPS_ALERT_POLICY=>RUNBOOK_FOR` |
| 2 | Planned downtime windows | `ZCA_OPS_DTWIN` (A) in the downtime app `ZUI_CA_OPS_DTW` (four-eyes) | finding mark `ZCA_OPS_FINDING-DOWNTIME_ID`; alert log D; exceptions app, daily control review, area dashboard; API `ZIF_CA_OPS_DOWNTIME` | `ZCL_CA_OPS_DOWNTIME_POLICY`, `ZCL_CA_OPS_DOWNTIME`, behaviour pool `ZBP_R_CA_OPSDOWNTIME` |
| 3 | Escalation until acknowledged | `ZCA_OPS_ALRULE-ESC_AFTER_MIN` / `ESC_REPEAT_MIN` / `ESC_MAX_COUNT` / `ESC_SEVERITY`, parameter `ESC_MAX_DEFAULT` | escalation e-mail per exception and step; alert log `ESC_STEP` | `ZIF_CA_OPS_ALERT=>ESCALATE`, report `ZCA_OPS_ESCALATE` |
| 4 | Alert correlation (parent / children) | `ZCA_OPS_CORR` (C) in `ZUI_CA_OPS_CFG` (*Alert correlation rules*) | one alert per parent with its children's count; alert log K; exceptions app facets *Correlated exceptions* / *Parent exception* | `ZCL_CA_OPS_CORRELATOR` (store), router |
| 5 | Response-time metrics (MTTA / MTTR) | parameter `METRIC_TIME_ZONE` | analytical list page `ZUI_CA_OPS_MET`; data points for an overview card | CDS only (`ZR_CA_OpsExcMetric`) |
| 6 | Shift handover | parameters `SHIFT_TIMES_<team>`, `SHIFT_TIMES_DEFAULT`, `SHIFT_TIME_ZONE` | list report `ZUI_CA_OPS_HOVR`; data points for an overview card | CDS only (`ZR_CA_OpsHandover`) |

## 1. Runbook link per check

**Configuration.** One row per check: area of the findings, finding field `RULE_ID`, `CHECK_CODE` or `GROUP2`
(exact value - the same fields as a control's covered checks), runbook URL (http / https), a one-line first action
(*"Call the bank's file desk, then re-send the ACK request"*), active. New rows by transport (DV1), like every
customizing row. **An active row needs a valid link** (checked on save, message 439); a row whose link is not known
yet keeps a placeholder and stays inactive - it is shown nowhere until the site's link is entered and the row is
activated.

**Which row applies.** `CHECK_CODE` before `GROUP2` (the check of the check registry) before `RULE_ID`; rows of
another area never apply. The same rule in CDS (`ZI_CA_OpsFindRunbook`) and in ABAP
(`ZCL_CA_OPS_ALERT_POLICY=>RUNBOOK_FOR`).

**Where.** Exceptions app: column *Runbook* (link) and facet *Runbook* (link and first action). Alert e-mail: keys
`RUNBOOK_URL` and `FIRST_ACTION` of the most severe finding of the message that has a row (template placeholders,
built-in layout lines). Other apps: associate `ZI_CA_OpsFindRunbook` by `RunId` / `FindingNo`.

## 2. Planned downtime windows

**What a window is.** Area, optional scope - PCRE patterns (complete value, case ignored, blank = any) on the
**check code**, the **object key** and the **interface or bank** (matched against GROUP1 or GROUP2 of the finding:
the producer's convention for interface / bank) - start and end, reason, planner, approver. Application data
planned in the productive client by operations (delivery class A), not customizing.

**Time zone.** Start and end are entered as local date and time in the time zone of the parameter
`DOWNTIME_TIME_ZONE` (default UTC); the zone is **stored with the window** when it is created, so the entry keeps
its meaning when the parameter changes later. On save the framework sets the UTC start and end from the entry
(`FROM_UTC` / `TO_UTC`, index `ARE`) - the values the store, the alert router and the API compare. Both are stored:
the local pair is what the planner entered (audit), the UTC pair is the operative value; they never disagree
because the zone is stored with the row.

**Four-eyes.** A window takes effect only when a **second user** approves it - ZCA_OPS activity **85** (approve) for
the area, the same activity as the waiver approval; the planner is refused (147) and never sees an enabled
*Approve* button. Planning needs 01, changing / deleting a window awaiting approval 02 / 06, *End now* 02. An
approved window is not changed any more (148): it ends **by itself** at its end (the status is derived from the
time, never stored), or earlier with *End now* (the end set to now; a window that had not started ends before it
started). Status: *Awaiting approval*, *Scheduled*, *Active*, *Ended* (domain `ZCA_OPS_DTW_STATUS`, translatable).

**Checks on save** (`ZCL_CA_OPS_DOWNTIME_POLICY=>VALIDATE`): start and end entered (158), end after start (143), at
most `DOWNTIME_MAX_HOURS` hours (144, default 24), start at most `DOWNTIME_PAST_TOL_MIN` minutes in the past (145,
default 15; a window is planned, never back-dated - not checked again once approved), reason (151), valid patterns
(150), **no overlapping window of the same scope** (146: same area and the same three patterns, approved or not,
not ended). Windows of different scope may overlap.

**Effect.**

| Where | What happens inside an approved window |
|---|---|
| Store (`ZCL_CA_OPS_STORE=>SAVE_FINDINGS`) | Findings are **recorded as usual** (exceptions with owner and SLA); each finding the window covers carries `DOWNTIME_ID` - set at write time because the patterns (PCRE) cannot be evaluated in CDS. One read of the area's windows per save. |
| Alert router (`DISPATCH`) | Findings with the mark are not alerted; the decision is logged in `ZCA_OPS_ALLOG` with the new status **D** (message 140: number of findings, window). A run-level trigger (RAG, abort) is held back only by an **area-wide** window (no pattern; message 157). The run-based escalation series ignores D and K rows. |
| Escalation (`ESCALATE`) | An exception a window covers now is skipped (counted as skipped) and escalated by the first job after the window. |
| Exceptions app | Column / filter *In planned downtime*, the window's ID on the object page. |
| Daily control review | *Findings in planned downtime* and the flag *Planned downtime* per slice (the status itself is unchanged: the findings are real). Counter `DowntimeCount` for a consumer's cards. |
| Area dashboard | *Planned downtime (area, now)* on the area-level slice and the number of active windows. |
| A consumer's check | `ZCL_CA_OPS_FACTORY=>GET_DOWNTIME( )->PLANNED( iv_area, is_finding, iv_from, iv_to )`: *is this period planned?* - e.g. a missing-volume or SLA check asks before raising "no file received" for a period that lies in a planned bank outage, and records an information finding instead. `AREA_PLANNED` for an area-wide window, `WINDOWS` for the list. |

**Purge.** Built-in target `DOWNTIME` of `ZCA_OPS_RETENTION`: windows whose end is older than
`DOWNTIME_RETENTION_DAYS` (default 400, at least 30). A finding's `DOWNTIME_ID` may then name a purged window: the
mark stays, the reason is gone - keep the retention at least as long as `RETENTION_DAYS_RUN`.

## 3. Escalation until acknowledged

**Rule fields** (`ZCA_OPS_ALRULE`, app `ZUI_CA_OPS_CFG`): `ESC_AFTER_MIN` (first escalation after the exception has
been open and unassigned for so many minutes), `ESC_REPEAT_MIN` (one more every so many minutes; 0 = once),
`ESC_MAX_COUNT` (at most; 0 = parameter `ESC_MAX_DEFAULT`, default 3; never more than 20), `ESC_SEVERITY` (severity
floor of the escalation; blank = the rule's `MIN_SEVERITY` - e.g. alert W, escalate only E). Destination: the rule's
`ESCALATION_DEST` on the rule's channel (the "escalation channel" is the escalation list of the rule; checked on save
as before, message 419).

**Job.** `ZCA_OPS_ESCALATE` (`ZIF_CA_OPS_ALERT=>ESCALATE`), one job per area every 5-15 minutes (the cadence bounds
how late a step goes out), ZCA_OPS **16** for the area. It reads the open queue of the area (disposition O - open
and unassigned, severity B / E / W, index OPN), applies every active rule with `ESC_AFTER_MIN`, and per exception
computes the **step due**: 0 before `ESC_AFTER_MIN`, then 1, then one more every `ESC_REPEAT_MIN`, capped by the
maximum (`ZCL_CA_OPS_ALERT_POLICY=>ESCALATION_STEP`). The step is derived from the exception's **first time seen**
(kept by the carry-forward), so it is the same whatever run raised the exception again and however often the job
runs.

**Once per step, logged per attempt.** Each step has its own alert intent (SHA-1 of rule, area, object, check code,
company code, first time seen and step; prefix `ESC`); the claim of the router (status C, unique index INT) makes a
step go out once even when two jobs run at the same time; a failed step is retried by the next job. Every attempt is
a row of `ZCA_OPS_ALLOG` with `ESC_STEP` = the step and `RUN_ID` / `FINDING_NO` = the exception's row. A job that
finds step 3 due while step 1 was the last sent sends step 3 (one message, not two).

**Stops when acknowledged.** Assigned (disposition A), waived, resolved - by a user or by the next run of the check
(auto-resolve) - the exception is no longer in the open queue: no further step. Also skipped: correlated children
(the parent escalates), exceptions inside an approved planned downtime window, the rule's quiet hours (severity B
excepted, as for alerts).

**Precedence and backward compatibility.** The run-based setting `ESCALATE_AFTER` (add `ESCALATION_DEST` to the
rule's own alert after n consecutive alerting runs) is unchanged for every rule **without** `ESC_AFTER_MIN`. A rule
**with** `ESC_AFTER_MIN` > 0 escalates by time only: its `ESCALATE_AFTER` is ignored (no double escalation of the same
problem). Throttling and the run-based series ignore escalation rows (`ESC_STEP` > 0), D and K rows.

## 4. Alert correlation (parent and children)

**Rules** (`ZCA_OPS_CORR`, app `ZUI_CA_OPS_CFG`): area, rule ID, check-code pattern (PCRE, blank = any), **key
fields** (comma list of `OBJECT_KEY`, `OBJECT_TYPE`, `GROUP1`, `GROUP2`, `RULE_ID`, `CHECK_CODE`, joined with `|`;
checked on save, 153), optional **key pattern** (PCRE with one capture group, applied to the joined value, complete
value: e.g. key fields `OBJECT_KEY`, pattern `([A-Z0-9_]+)/.*` = the bank of a file key `BANK_A/FILE_0001`), **window**
in minutes (at least 1, 154), active. When several active rules of the area select a finding, the lowest rule ID
decides.

**Parent and children.** When the store records a **new open exception** (not one carried forward), the correlator
builds its key; the **company code is always part of the key**. If an open parent of the key exists whose window
(from its first time seen) still runs - or an earlier exception of the same key in the same save - the exception
becomes its **child**; otherwise it is a new **parent**. A child keeps all its own data (no copied payload); the
correlation adds three fields to the finding: `CORR_ID` (the group), `CORR_ROLE` (P / C) and `CORR_KEY` (SHA-1 of
area, rule, company code and key value - how the parent of a new exception is found, index `COR`).

**Decision: a correlation ID, not a parent pointer.** A pointer to the parent's row (run ID + finding number) would
dangle at the parent's next run: the carry-forward supersedes the row and writes a new one each time the check raises
the exception again. A group ID is inherited by the carry-forward exactly like owner and reason code, so parent and
children stay linked however often they are raised; the parent's current row is found by `CORR_ID` and role P
(index `CRI`).

**Alerts.** The router sends **one alert for the parent**; its message names the number of **open children**
(`CORRELATED_COUNT`). Children are not alerted on their own - also children that arrive in later runs inside the
window; the decision is logged with the new status **K** (message 141). A parent carried forward is not re-alerted
(repeat rule, as before).

**Exceptions app.** On a parent: facet *Correlated exceptions* (its children, each row under its own read
authorisation) and *Open correlated exceptions*; on a child: facet *Parent exception*; columns / filters *Correlation
role*.

**Resolving stays per exception. Decision: no separate action "resolve correlated".** The table *Correlated
exceptions* is a list of the same entity, so its toolbar offers the existing *Resolve* action on **several selected
rows** - one dialog, one reason, every child checked with its own instance authorisation (ZCA_OPS 02 with its company
code) and its own ETag, every child with its own history row. A second action would duplicate the resolve path and
its rules for no added capability, and a bulk resolve of all children behind one click would close exceptions the
user has not looked at. Resolving a parent does not resolve its children (the next run of the check auto-resolves the
ones that recovered).

**Company-code isolation.** Because the company code is part of the key, a parent and its children always have the
same company code: the DCL rule of the exceptions app applies to every child, a child is never linked to an exception
of another company code, and the open-children count (`ZI_CA_OpsCorrCount`) never mixes company codes
(`docs/auth_zca_ops.md` §3c).

## 5. Response-time metrics (MTTA / MTTR)

Read-only CDS over `ZCA_OPS_FINDING` and `ZCA_OPS_EXC_HIST`, nothing stored. **One row per exception episode**: the
current row of an exception (not superseded, not information) - the carry-forward keeps one current row per
exception and carries its first time seen, so an episode is area, object, check code, company code and first time
seen (`ZI_CA_OpsExcEpisode`).

| Measure | Definition |
|---|---|
| Raised | 1 per episode |
| Time to assign (MTTA) | first time seen → first `ASSIGN` of the exceptions app on any row of the episode (`ZI_CA_OpsExcAssign1`); minutes, average over the assigned episodes (null when never assigned - averages ignore it) |
| Time to resolve (MTTR) | first time seen → resolution (`RESOLVED_AT`: a user or the auto-resolve of the next run), resolved episodes |
| Open by age | open / assigned episodes by minutes since the first raise |
| Re-opened | an episode whose object, check and company code had an earlier **resolved** episode (`ZI_CA_OpsExcReopen`) |
| Distribution | CDS has no percentile function: **time buckets** instead - assigned within 15 min / 1 h / 4 h / 1 day / later / never; resolved within 1 h / 4 h / 1 day / 3 days / later; open < 1 day, 1-3, 3-7, > 7 days (bounds `ZIF_CA_OPS_RESP_TYPES=>GC_METRIC_SECONDS`). A percentile is read from the cumulative buckets. |

**Dimensions:** area, **team** (the team of the active controls that cover the check - `ZI_CA_OpsCheckTeam` /
`ZI_CA_OpsFindTeam`, CHECK_CODE before GROUP2 before RULE_ID; blank where no control covers the check), check code,
severity, company code, month (`YYYYMM`) and week (`YYYYWW`, `I_CalendarDate`) of the raise in `METRIC_TIME_ZONE`.

**Apps.** Analytical list page on `ZUI_CA_OPS_MET` (entity `ExceptionMetric`; charts *Raised and resolved per
month*, *Minutes to assign and to resolve*, *Open exceptions by age*); data points `Raised`, `Mtta`, `Mttr`, `Open`,
`Reopened` for a consumer's overview card (sums and averages over the rows the user may read). DCL
`ZC_CA_OPSEXCMETRIC`: the company-code rule - the company code is a dimension, so a sum or an average after the DCL
never includes another company code's exceptions.

## 6. Shift handover

**Shift definitions.** Per team a parameter `SHIFT_TIMES_<team>` of area `CA_OPS` (kind S, value type TIME: one row
per shift start, `HHMMSS`, local time of `SHIFT_TIME_ZONE`), delivered by the consumer for its teams (the values of
`CONTROL_TEAMS`); `SHIFT_TIMES_DEFAULT` (delivered `000000`: one shift a day from midnight) for teams without own
times and for exceptions of no team. CDS reads the parameter tables with the API's resolution (maintained rows, else
the definition default), as `CONTROL_TIME_ZONE`.

**Since when.** "Since the start of the previous shift" of the team: of the candidate starts (every start time on
the dates from two days before to two days after today) the current shift began at the latest start not after now,
the previous at the latest start before that (`ZI_CA_OpsShiftCand` ... `ZI_CA_OpsShiftWin`).

**Per team, area and company code** (`ZR_CA_OpsHandover`, list report `ZUI_CA_OPS_HOVR`, entity `ShiftHandover`):
new exceptions (first raised since), resolved since, still open (open or assigned now), escalations sent since,
controls of today awaiting sign-off (daily control review), planned downtime windows active now and starting before
the end of the next shift (a window has no team: every team with shift times sees the windows of the areas it may
read). *Needs attention* = open or escalated exceptions or controls awaiting sign-off. Data points `New`,
`Resolved`, `Open`, `Escalated`, `AwaitingSignOff`, `DowntimeNext` for an overview card. DCL `ZC_CA_OPSHANDOVER`:
the company-code rule.

**Decision: no handover note table.** "No incidents in SAP" is a user decision, and a handover note is not an
incident - but it is free text keyed by **team and shift**, and a team is not an authorisation dimension: the
framework's read rule protects rows by area and company code (`docs/auth_zca_ops.md` §3c), and a free-text note of
a team spans the areas and company codes of that team. A note that names a company code's payment problem would be
shown to every reader of the team's handover, which the company-code isolation exists to prevent. The narrative per
control and slice already has its place under that rule: the observation and next action of the daily control
review's sign-off. So the handover stays **derived only** (nothing stored, nothing to purge); the shift's free-text
note stays in the team's existing channel. If the user wants a note in SAP, the safe shape is one note per **area and
company-code slice** and shift (the review's sign-off pattern), not per team - a decision for the user, not built.

## 6a. Concurrency, transactions and failure handling

| Situation | Behaviour | Why it is acceptable |
|---|---|---|
| Two runs of different variants of one area correlate at the same moment | Each run reads the open parents before it saves; both can open a parent for the same key (two parents, each with its children) | No lock across runs (a run must never wait for another variant). The next run of either variant joins new findings to the newest open parent of the key; the other parent resolves with its own findings. Each parent shows its children in the exceptions app |
| Escalation job and an assignment at the same moment | The job reads the candidates (open, unassigned) once; an assignment after that read can still receive one more step | At most one extra mail per exception and job; the next job no longer selects it. The step is claimed by intent key (unique index `INT`), so two jobs never send the same step twice |
| Escalation step whose intent key cannot be built | Logged `F` with message 160, counted as failed, not sent | Without the key the step done is not recognised and every job would resend it |
| Failed escalation step (channel inactive, transport error) | Logged `F`; the next job tries the same step again while the exception stays open and unassigned | The intent of a failed step is not claimed (`STEPS_DONE` counts `S`, claimed and partial only) |
| Two planners create overlapping windows at the same moment | Both validations pass (each sees only saved windows); two overlapping windows exist | The duplicate check is a convenience, not a constraint: overlapping windows are harmless (a finding is planned if any window covers it) and the approver sees both in the app |
| Commits | Unchanged pattern: an escalation step goes through the router's existing delivery - durable claim committed through `ZIF_CA_OPS_STORE~COMMIT` before the send, result committed after (A17). The downtime, correlator and policy classes never commit; the downtime app writes only in the RAP save sequence (no `COMMIT WORK` in the behaviour pool) | The claim is the evidence of the attempt even when the send fails after it |

**Downtime app and side effects.** The app has no draft and no field that is recalculated while the user types:
the UTC pair and the time zone are set on save, the status is a calculated element, and both actions return
`$self`, so the object page shows the new values after save or action without a side-effects declaration.

**Metrics as an analytical list page, not an analytical query.** `ZC_CA_OpsExcMetric` is a transactional query
with `@Aggregation.default` (#SUM / #AVG) for the OData V4 aggregation of the analytical list page and the overview
card. A cube (`@Analytics.dataCategory: #CUBE`) with a transient analytical query (`provider contract
analytical_query`, averages as `#FORMULA`) would add the multidimensional report and analytics cloud live access;
it is not built (decision for the user, see the build report). The DCL sits on the exposed projection, as for every
other app of the framework.

## 7. Objects

| Kind | Objects |
|---|---|
| Tables | `ZCA_OPS_RUNBOOK`, `ZCA_OPS_CORR` (C, drafts `ZCA_D_RUNBOOK`, `ZCA_D_CORR` generated), `ZCA_OPS_DTWIN` (A); new fields `ZCA_OPS_FINDING-DOWNTIME_ID`, `-CORR_ID`, `-CORR_ROLE`, `-CORR_KEY` (indexes `COR`, `CRI`), `ZCA_OPS_ALRULE-ESC_AFTER_MIN`, `-ESC_REPEAT_MIN`, `-ESC_MAX_COUNT`, `-ESC_SEVERITY` (draft `ZCA_D_ALRULE` regenerated), `ZCA_OPS_ALLOG-ESC_STEP`, `-FINDING_NO`; domain / data element `ZCA_OPS_DTW_STATUS` |
| ABAP | `ZIF_CA_OPS_RESP_TYPES`, `ZIF_CA_OPS_DOWNTIME`, `ZCL_CA_OPS_DOWNTIME`, `ZCL_CA_OPS_DOWNTIME_POLICY`, `ZCL_CA_OPS_CORRELATOR`, report `ZCA_OPS_ESCALATE`; changed: router, alert policy, alert DAO (`GET_MARKS`, `GET_CHILD_COUNTS`, `GET_RUNBOOKS`, `GET_ESCALATION_CANDIDATES`, `GET_INTENT_LOG` - DEFAULT IGNORE), `ZIF_CA_OPS_ALERT=>ESCALATE` (DEFAULT IGNORE), store, purge (target `DOWNTIME`), factory / injector (`GET_DOWNTIME` / `INJECT_DOWNTIME`), configuration checks (`LINK_VALID`, `KEY_FIELDS_VALID`, `WINDOW_MIN_VALID`), built-in mail layout (L16-L19), params adapter (six prefixes) |
| Configuration app | `ZUI_CA_OPS_CFG` regenerated: entities `RunbookLink`, `CorrelationRule`; alert rule escalation fields |
| Downtime app | `ZR_CA_OpsDowntime`, `ZC_CA_OpsDowntime` (+ BDEFs, DDLX, DCL), `ZI_CA_OpsDtwStatusT`, behaviour pool `ZBP_R_CA_OPSDOWNTIME`, service `ZUI_CA_OPS_DTW`; `ZI_CA_OpsDtwNow`, `ZI_CA_OpsDtwActive` |
| Exceptions app, review, dashboard | `ZR_CA_OpsException` / `ZC_CA_OpsException` (+ BDEF, DDLX), `ZI_CA_OpsFindRunbook`, `ZI_CA_OpsCorrCount`; `ZI_CA_OpsCtlFind` ... `ZR_CA_OpsCtlReview` / `ZC_CA_OpsCtlReview` (downtime mark); `ZR_CA_OpsCheckStatus` / `ZC_CA_OpsCheckStatus` (downtime mark) |
| Metrics | `ZI_CA_OpsMetricTz`, `ZI_CA_OpsCheckTeam`, `ZI_CA_OpsFindTeam`, `ZI_CA_OpsExcEpisode`, `ZI_CA_OpsExcAssign1`, `ZI_CA_OpsExcReopen`, `ZI_CA_OpsExcTimes`, `ZR_CA_OpsExcMetric`, `ZC_CA_OpsExcMetric` (+ DDLX, DCL), service `ZUI_CA_OPS_MET` |
| Shift handover | `ZI_CA_OpsShiftTz`, `ZI_CA_OpsShiftDef`, `ZI_CA_OpsShiftCand`, `ZI_CA_OpsShiftCur`, `ZI_CA_OpsShiftPrev`, `ZI_CA_OpsShiftNext`, `ZI_CA_OpsShiftNEnd`, `ZI_CA_OpsShiftWin`, `ZI_CA_OpsHovrEvt`, `ZI_CA_OpsHovrSum`, `ZR_CA_OpsHandover`, `ZC_CA_OpsHandover` (+ DDLX, DCL), service `ZUI_CA_OPS_HOVR` |
| Messages | `ZCA_OPS` 140-160 (153 / 154: configuration app) |
| Tests | `ZCL_CA_OPS_DOWNTIME_POLICY` (14), `ZCL_CA_OPS_DOWNTIME` (4, OSQL), `ZCL_CA_OPS_CORRELATOR` (9), `ZCL_CA_OPS_ALERT_ROUTER` (`ltc_response`, 9), `ZCL_CA_OPS_ALERT_POLICY` (`ltc_response`, 9), `ZCL_CA_OPS_STORE` (3 new), `ZCL_CA_OPS_PURGE_DAO` (`ended_window_is_deleted`), `ZCL_CA_OPS_CFG_CHECKS` (`ltc_response_check`, 3), `ZCL_CA_OPS_FACTORY` (2 new), CDS tests `ZCL_CA_OPS_MET_CDS_TEST` (`ltc_assign`, `ltc_reopen`, `ltc_times`, `ltc_metric`) and `ZCL_CA_OPS_HOVR_CDS_TEST` (`ltc_current`, `ltc_previous`, `ltc_events`); the downtime behaviour pool is exempt (every rule in the policy; QA1) |

## 8. VERIFY

`docs/VERIFY.md` V70-V79 (a consumer's configuration and cards: its own items, e.g. V80 / V81 of the first consumer).

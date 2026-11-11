# Message class ZCA_OPS

Messages of the operations framework ZCA_OPS (package `ZCA_OPS`). Numbers of messages that moved from
the message class of its first consumer are kept (the consumer's nnn = ZCA_OPS nnn), new messages use free
numbers of the same range. Ranges: 001-099 runs, store, alerting, plug-ins, lock, authorisation, version
and area checks, purge, exception lifecycle (classification 068), alert e-mail templates (070-075), daily
control review (076-080) · 082-103 check registry, generic runner, no-code aggregate check and
process onboarding check (2026-11-10; 082 / 083 also the table and field checks of the configuration app) · 110-139 SAP job
monitor (2026-11-11) · 140-179 operations response features (2026-11-11: planned downtime, correlation, escalation until acknowledged; 153 / 154 checks of the configuration app; `docs/OPERATIONS_FEATURES.md`) · 210-239 link registry and walker (2026-11-11; 225, 235, 236 checks of the configuration app; `docs/LINK_REGISTRY.md`) · 400-449 configuration apps (RAP) · 700-849 alert patterns,
exception concurrency, application log, alert IDs, run abort, e-mail, logical file paths · 900-909 the
optional demo consumer `ZCA_OPS_DEMO` (sub-package `src/demo`; unused when the demo is not installed).
Every user-facing text of the framework is one of these messages (built with `ZCL_CA_OPS_UTIL=>TEXT( )`
or raised with `MESSAGE eNNN(zca_ops)`) or a text symbol (`docs/text_elements/`); numbers are referenced
through the `gc_msg-*` constants of the types interfaces. `tools/abapgit_serialize.py` writes the message
class from this file; create it in SE91 exactly as listed only when not installing with abapGit (short
texts <= 73 characters).

| No. | Text |
|---|---|
| 000 | &1 &2 &3 &4 |
| 001 | Run ID could not be generated |
| 002 | [&1] run &2 ended &3 / RAG &4 |
| 003 | [&1][&2] &3: &4 finding(s) |
| 004 | Run &1 status &2, RAG &3, items &4, |
| 005 | failed &1, blocked &2. |
| 006 | &1 more finding(s): see the exceptions app (Fiori ZUI_CA_OPS_EXC). |
| 007 | Channel &1 not configured or inactive in ZCA_OPS_ALCHN |
| 008 | Passed on re-run &1 |
| 010 | Insert into table &1 failed |
| 011 | Update of table &1 failed |
| 020 | Alert for route &1 could not be sent |
| 021 | Alert rule &1 has no recipient |
| 025 | Application log &1/&2 written only in part (&3 of &4 lines) |
| 026 | E-mail for &1 was not accepted by SAPconnect (BCS send result) |
| 027 | Alert route &1: &2 is not a shared SO23 distribution list |
| 030 | Class &1 does not exist |
| 031 | Class &1 cannot be instantiated as a plug-in |
| 032 | Class &1 does not implement interface &2 |
| 033 | Plug-in interface &1 does not exist |
| 040 | Run for &1 &2 is already active (lock held by &3) |
| 041 | No authorization for &1 activity &2 |
| 042 | Lock service failed for &1 &2 (run not started) |
| 043 | Area &1 is not an active parameter area of ZCA_PARAM (ZCA_PARAM_AREA) |
| 044 | ZCA_OPS &1 needs ZCA_PARAM &2 or later (installed: &3) |
| 060 | Purge &1: &2 row(s) older than &3 (&4) |
| 061 | Exception is closed (disposition &1): no further action possible |
| 062 | A reason is required |
| 063 | Four-eyes: &1 requested this and cannot approve it |
| 064 | No waiver request is pending for this exception |
| 065 | Waiver end date &1 is in the past |
| 066 | An owner (user) is required |
| 067 | A waiver request by &1 is already pending |
| 068 | Reason code &1 is not allowed (parameter EXC_REASON_CODES) |
| 070 | E-mail renderer &1 not available in this system - built-in layout sent |
| 071 | E-mail template &1 not found or inactive &2 - built-in layout sent |
| 072 | E-mail template &1 not rendered &2 - built-in layout sent |
| 073 | E-mail template &1 has no placeholder for &2 - table added at the end |
| 074 | [&1][&2] &3: &4 finding(s), |
| 075 | E-mail template &1 not used: ALERT_MAIL_RENDERER is BUILTIN |
| 076 | Action required: enter the observation and the next action |
| 077 | Result &1 differs from the derived status: enter the observation |
| 078 | &1 is not a control status (H healthy, W watch, A action required) |
| 079 | Control &1 for &2 is being reviewed by &3 |
| 080 | Lock service failed for the review of control &1 for &2 |
| 081 | Alert audit log incomplete: &1 of &2 row(s) not saved (ZCA_OPS_ALLOG) |
| 082 | Table &1 does not exist in the ABAP Dictionary |
| 083 | &1 is not a field of table &2 |
| 084 | Check &1 of area &2 failed: |
| 085 | No active check registered for area &1, schedule group &2 |
| 086 | Table &1 is not approved for area &2 (ZCA_OPS_TABWL) |
| 087 | No authorisation to display table &1 (S_TABU_NAM) |
| 088 | Operator &1 is not allowed for field &2 |
| 089 | &1 is not a number (field &2) |
| 090 | Aggregate &1: function &2 is not COUNT or AGE |
| 091 | Aggregate &1: &2 is not a date field of table &3 |
| 092 | Check &1 of area &2 has no active aggregate row (ZCA_OPS_AGG) |
| 093 | Aggregate &1 could not be read from table &2 |
| 094 | &1 &2: &3 row(s) match (limit &4) |
| 095 | &1 &2: the oldest row is &3 day(s) old (limit &4) |
| 096 | Process &1 of area &2 has no active check (ZCA_OPS_CHECK) |
| 097 | Process &1 of area &2: check &3 is covered by no active control |
| 098 | Process &1: no active alert rule for area &2 (ZCA_OPS_ALRULE) |
| 099 | Process &1 of area &2: owner &3 missing or not a user of this client |
| 100 | Process &1 of area &2: purge target &3 missing or inactive |
| 101 | Process &1 of area &2: no role named or area not active (&3) |
| 102 | Area &1 group &2: &3 check(s) run, &4 finding(s) |
| 103 | Aggregate &1: company-code field required (check &2 is per company) |
| 110 | Job &1 (&2) cancelled at &3 &4 |
| 111 | Job &1 (&2) failed under root job &3 (&4) - the root did not abort |
| 112 | Job &1 (&2) finished with &3 error line(s) in its job log |
| 113 | Job &1 (&2) active for &3 minutes (limit &4) |
| 114 | Job &1 (&2) not started &3 minutes after its planned start (limit &4) |
| 115 | Job &1 (&2): failure reported by &3 - kept as evidence only |
| 116 | Parent job: &1 (&2), status &3, link &4 |
| 117 | Root job: &1 (&2), status &3, &4 level(s) above |
| 118 | Scheduler job: &1 / &2, criticality &3 |
| 119 | Step &1: program &2, variant &3, user &4 |
| 120 | Job monitor &1: &2 read, cap &3 - the next run continues at &4 |
| 121 | Job monitor parameter &1 is not usable (&2) |
| 122 | Job monitor plug-in &1 failed - its links or objects are missing: |
| 123 | Job log of &1 (&2) not read: BP_JOBLOG_READ return code &3 |
| 124 | Failed jobs in this run under the same check: &1 |
| 125 | Application logs: &1 linked (&2 with errors), first &3 / &4 |
| 126 | Business object &1 &2: &3 (quality &4) |
| 127 | &1 is not a field of the job table or not a valid field name |
| 128 | Root job &1 (&2) still active - its scheduler has not seen the failure |
| 129 | Job evidence of area &1 / check &2 could not be saved |
| 130 | SM37: job &1 count &2, system &3, server &4 |
| 140 | &1 finding(s) in planned downtime &2: recorded, not alerted |
| 141 | &1 correlated exception(s) alerted with their parent only |
| 142 | Escalation &1 of &2 (open and unassigned for &3 min): |
| 143 | Downtime window: the end &1 is not after the start &2 |
| 144 | Downtime window of &1 hour(s) is longer than &2 (DOWNTIME_MAX_HOURS) |
| 145 | Downtime window starts &1 minute(s) in the past (allowed: &2) |
| 146 | Downtime window overlaps window &1 of the same scope |
| 147 | Four-eyes: &1 planned this window and cannot approve it |
| 148 | Downtime window is approved: only End now is possible |
| 149 | Downtime window has ended: no further change |
| 150 | Scope pattern &1 is not valid PCRE (complete value, any case) |
| 151 | Enter the reason of the planned downtime |
| 152 | No authorisation for area &1, activity &2 (ZCA_OPS) |
| 153 | Key field list &1 invalid (finding fields, comma separated) |
| 154 | Correlation window &1 must be at least 1 minute |
| 155 | Correlation ID could not be generated - findings not saved |
| 156 | Escalation of area &1: &2 escalated, &3 skipped, &4 failed |
| 157 | Run-level alert of rule &1 suppressed: planned downtime &2 |
| 158 | Enter the start and the end of the window (date and time) |
| 159 | Downtime window awaits approval: change or delete it instead |
| 160 | Escalation step &1 of rule &2 not sent: no intent key (duplicate guard) |
| 210 | Link registry: object &1 is not defined or not active |
| 211 | Walk from &1: key field &2 has no value |
| 212 | Link registry: &1 (&2) is not approved for area &3 (ZCA_OPS_TABWL) |
| 213 | Link registry &1: &2 is not a field of &3 |
| 214 | Link &1 condition &2: kind &3 is not supported or incomplete |
| 215 | Link &1: transform &2 &3 is not valid |
| 216 | Link &1: fallback chain is cyclic (fallback of &2) |
| 217 | Link &1: cardinality &2 needs the keys of &3 or a PREFER condition |
| 218 | Link &1 is active, but field &2 is VERIFY (&3) |
| 219 | Walk from &1 stopped at depth &2 (LINK_MAX_DEPTH) |
| 220 | Walk from &1 stopped after &2 objects (LINK_MAX_NODES) |
| 221 | Link &1: read capped at &2 rows (LINK_MAX_ROWS) |
| 222 | Link &1: read of &2 failed |
| 223 | Link &1: sensitive field &2 as a constant or preferred value |
| 224 | Link &1 replaces &2, which is not a link of a lower layer |
| 225 | &1 is not TABLE-FIELD of a field of the ABAP dictionary |
| 226 | Link &1: &2 belongs to the higher layer &3 |
| 227 | Link &1 condition &2: &3 is not a number (field &4) |
| 228 | Link registry: &1 effective link(s), &2 problem(s) |
| 229 | Link &1: &2 is not a link |
| 230 | Link &1: &2 links other objects |
| 231 | &1 does not start with the prefix &2 of layer &3 |
| 232 | Object &1: key field &2 is missing, hidden or of another layer |
| 233 | &1: layer &2 is not defined |
| 234 | Link &1: &2 is not a field of &3 (source &4) |
| 235 | &1 is required when &2 is '&3' |
| 236 | &1 must be blank when &2 is '&3' |
| 402 | Enter a customizing request: changes in this client are recorded |
| 403 | Transport request &1 does not exist |
| 404 | &1 is not a customizing request or customizing task |
| 405 | Transport request &1 is released or no longer modifiable |
| 408 | Changes could not be recorded on transport request &1 |
| 410 | Class &1 does not exist or does not implement &2 |
| 413 | Value &1 is not allowed for &2 (allowed: &3) |
| 414 | Enter both &1 and &2, or neither |
| 418 | &1 is not a valid PCRE pattern (matched to the whole value, any case) |
| 419 | Channel &1 cannot deliver to &2 (e-mail: shared SO23 list name) |
| 434 | Parameter &1 is not defined in area &2 (ZCA_PARAM) |
| 435 | &1 is not a parameter area of ZCA_PARAM_AREA (or * for every area) |
| 436 | &1 is not an e-mail template ID (SMTG, upper case) or does not exist |
| 437 | &1 is not a user of this client |
| 438 | Team &1 is not a value of parameter CONTROL_TEAMS |
| 439 | &1 is not an http:// or https:// link (no blanks) |
| 742 | Alert rule &1: pattern &2 is not valid PCRE - rule not applied |
| 786 | Exception &1 (&2) changed by a user during the run - left for next run |
| 787 | Exception &1 / &2 changed meanwhile - not resolved, nothing saved |
| 800 | Application log &1/&2 not created (BAL_LOG_CREATE return code &3) |
| 801 | Application log &1/&2 not saved (BAL_DB_SAVE return code &3) |
| 802 | Alert log ID could not be generated - alert not delivered |
| 803 | Run &1, job &2 / &3 - exceptions app ZUI_CA_OPS_EXC |
| 804 | Run &1 &2 aborted by an error: |
| 805 | Alert dispatch failed for the run of &1: |
| 806 | E-mail for &1: SAPconnect commit failed (return code &2) |
| 807 | File &2 not resolved or not valid in logical path / file name &1 (FILE) |
| 808 | File name &1 not allowed: enter a name only, without a path or .. |
| 809 | No authorisation to &2 file &1 (S_DATASET) |
| 900 | Jobs ended in the last &1 hours: &2 (cancelled &3, late &4) |
| 901 | &1 job(s) cancelled in the last &2 hours (SM37) |
| 902 | &1 released job(s) not started &2 minutes after their planned start |
| 903 | Demo run of area &1: &2 finding(s), RAG &3 - &4 |

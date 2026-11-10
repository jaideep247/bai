# Message class ZCA_OPS

Messages of the operations framework ZCA_OPS (package `ZCA_OPS`). Numbers of messages that moved from
the message class of its first consumer (ZCD_OPS) are kept (ZCD_OPS nnn = ZCA_OPS nnn), new messages use free
numbers of the same range. Ranges: 001-099 runs, store, alerting, plug-ins, lock, authorisation, version
and area checks, purge, exception lifecycle (classification 068), alert e-mail templates (070-075), daily
control review (076-080) · 082-103 check registry, generic runner, no-code aggregate check and
process onboarding check (2026-11-10; 082 / 083 also the table and field checks of the configuration app) · 400-449 configuration apps (RAP) · 700-849 alert patterns,
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

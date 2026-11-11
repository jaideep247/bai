# Parameters of the operations framework (ZCA_PARAM area CA_OPS)

> **First principle:** the framework reads only its own area; a consumer adds names, never logic.
> **Analogy:** a shared switchboard with labelled sockets — the framework wires a few, each tenant labels its own.

Area `CA_OPS` (`config/param_areas.csv`); definitions `config/param_definitions.csv`, generated into
`ZCL_CA_OPS_PARAM_SEED` by `tools/param_definitions.py` (check `param_definitions` of `tools/checks.py`).
Read through `ZCL_CA_OPS_FACTORY=>GET_PARAMS( )`: a name with prefix `ALERT_`, `SLA_`, `RETENTION_` or
`PURGE_`, `CONTROL_`, `EXC_`, `CHECK_` or `JOB_` - and, for the operations response features (2026-11-11), `RUNBOOK_`,
`DOWNTIME_`, `ESC_`, `CORR_`, `METRIC_` or `SHIFT_` - and, for the link registry walker (2026-11-11), `LINK_` - and, for the process catalogue (2026-11-11), `CAT_` - and, for build F (2026-11-11), `BRK_` (break analysis) and `PILOT_` (pilot pack) - is read in `CA_OPS`; a value the framework resolves (maintained value or definition default)
wins over the caller's default; an unreadable parameter is listed by `GET_ERRORS( )`, never silent.

| Name | Type | Default | Read by | Meaning |
|---|---|---|---|---|
| `ALERT_DEFAULT` | LIST | — | `ZCL_CA_OPS_ALERT_ROUTER=>SEND` | Recipients (shared SO23 lists) when `ALERT_<route>` is blank |
| `ALERT_ESCALATION_WINDOW_H` | INT ≥ 1 | 24 | alert router | Look-back window of the escalation series of a rule (hours) |
| `ALERT_SECTION_CLASS` | CLASS (`ZIF_CA_OPS_ALERT_SECTION`) | — | alert router | A consumer's own section of the alert message (blank = none) |
| `ALERT_MAIL_RENDERER` | CHAR (`SMTG\|BUILTIN`) | SMTG | alert router | Alert e-mails from SAP e-mail templates (built-in layout when not usable) or the built-in layout only |
| `ALERT_TEMPLATE_DEFAULT` | CHAR (template ID) | ZCA_OPS_ALERT_DEFAULT | alert router | Generic e-mail template when neither rule, section nor channel names one |
| `ALERT_TIME_ZONE` | CHAR (TTZZ zone) | UTC | alert policy (via router) | Time zone of the run start / end shown in the alert e-mail |
| `ALERT_EXC_APP_LINK` | CHAR | — | alert policy (via router) | Link to the exceptions app in the alert e-mail (blank = the app's name) |
| `BRK_LEDGER` | CHAR | 0L | break analysis (`docs/BREAK_ANALYSIS.md`) | Ledger of the journal lines when the account names none |
| `BRK_LOOKBACK_DAYS` / `BRK_FORWARD_DAYS` | INT | 62 / 10 | break analysis | Days of lines before the key date / after it (lines that may clear a group) |
| `BRK_MAX_GROUPS` / `BRK_MAX_ITEMS` / `BRK_PACKAGE_SIZE` / `BRK_LINK_MAX_ROWS` | INT | 20 000 / 200 000 / 500 / 5 000 | break analysis | Caps of one account (partial beyond) and the size of a line read / linked-row read |
| `BRK_TIMING_DAYS` | INT 0-10 | 3 | product rules (@ value) | Last days of a month / days to clear that count as timing |
| `BRK_DOCTYPES_RETRIEVAL` / `BRK_DOCTYPES_RETURN` | LIST | - | product rules (@ value) | Document types of a retrieval / a return that clear a group |
| `BRK_BTC_NEW` / `_REDEPOSIT` / `_CHEQUE` / `_CUMULATED` | LIST | - | a customer's rules (@ value) | Bank transaction code lists (the customer maintains the codes) |
| `BRK_UNEXPLAINED_DAYS` / `BRK_STALE_DAYS` / `BRK_MAX_FINDINGS` | INT | 5 / 2 / 500 | `ZCL_CA_OPS_CHK_BREAK` | Age of an unexplained break that is an exception; age of a stale snapshot; findings per account |
| `BRK_KEY_DATE_LAG` | INT 0-31 | 1 | `ZCA_OPS_BRK_RUN` | Key date without one: today minus these days |
| `RETENTION_DAYS_BREAK` | INT ≥ 30 | 400 | purge target `BREAK` | Break analysis snapshots (the latest per account is kept) |
| `PILOT_FP_REASON` | CHAR | NOT_AN_ISSUE | pilot CDS (`ZI_CA_OpsPilotCfg`) | Reason code that marks a resolved exception a false positive (`docs/PILOT_PACK.md`) |
| `PILOT_WINDOW_DAYS` | INT 1-400 | 30 | `ZCA_OPS_PILOT_EXPORT` | Days the export covers without a from date |
| `PILOT_EXPORT_PATH` / `PILOT_EXPORT_FILE` | CHAR | - | `ZCA_OPS_PILOT_EXPORT` | Logical path / logical file name (FILE) of the export |
| `CAT_OUTAGE_DAYS` | INT 1-31 | 3 | outage check `ZCL_CA_OPS_CHK_OUTAGE` (`docs/PROCESS_CATALOGUE.md` §6) | Days back the check evaluates approved planned downtime windows that ended |
| `CAT_OUTAGE_MARGIN_DAYS` | INT 0-7 | 1 | outage check | Days after a window that an aggregate row without a time field covers (G/L transfer around the outage) |
| `CHECK_STALE_MIN_DEFAULT` | INT ≥ 1 | 1500 | area dashboard CDS (`ZI_CA_OpsChkStaleD`) | Minutes after which the latest completed run of an area and schedule group is stale on the area dashboard `ZUI_CA_OPS_DASH` when the area has no `CHECK_STALE_MIN_<area>` (process onboarding, 2026-11-10) |
| `CONTROL_TIME_ZONE` | CHAR (TTZZ zone) | UTC | control review CDS (`ZI_CA_OpsCtlTz`) | Time zone of the business date of a control, of its review cut-off and of the sign-off time shown (a consumer delivers its value row, e.g. `CST`) |
| `CONTROL_TEAMS` | LIST | ONSITE,OFFSHORE | `ZCL_CA_OPS_CFG_CHECKS=>TEAM_VALID` | Teams a control may name (control register, checked on save) |
| `DOWNTIME_MAX_HOURS` | INT ≥ 1 | 24 | downtime app (check on save) | Longest planned downtime window (hours, message 144; operations response features 2026-11-11) |
| `DOWNTIME_PAST_TOL_MIN` | INT ≥ 0 | 15 | downtime app (check on save) | Minutes a new window may start in the past (145) - a window is planned, never back-dated |
| `DOWNTIME_RETENTION_DAYS` | INT | 400 | purge (built-in target DOWNTIME) | Ended downtime windows (by their end; at least 30 applied) |
| `DOWNTIME_TIME_ZONE` | CHAR (TTZZ zone) | UTC | downtime app (stored with a new window) | Time zone in which start and end of a window are entered |
| `ESC_MAX_DEFAULT` | INT 1-20 | 3 | alert router (`ESCALATE`) | Escalations of one exception when the rule's `ESC_MAX_COUNT` is 0 |
| `EXC_REASON_CODES` | LIST | TIMING,INVESTIGATING | exceptions app (action *Classify*) | Reason codes an open exception may be classified with |
| `LINK_MAX_DEPTH` | INT 1-10 | 4 | link registry walker (`docs/LINK_REGISTRY.md` §5) | Levels a walk follows from its start object; a request may ask for fewer, never more (219 when links were left) |
| `LINK_MAX_ROWS` | INT 1-10 000 | 100 | link registry walker | Rows one read of a link returns at most (per level and chunk; 221 when reached) |
| `LINK_MAX_NODES` | INT 1-5 000 | 500 | link registry walker | Objects one walk returns at most (220: the walk stops) |
| `LINK_READ_CHUNK` | INT 1-1 000 | 100 | link registry walker | Source rows per database read of a link (IN list or OR groups) |
| `JOB_LOOKBACK_MIN` | INT ≥ 1 | 60 | SAP job monitor (`docs/JOB_MONITORING.md` §3) | Minutes read back by the first run of an area and check (no watermark yet) |
| `JOB_OVERLAP_MIN` | INT ≥ 0 | 10 | SAP job monitor | Minutes re-read before the watermark (jobs already kept are not reported again) |
| `JOB_MAX_JOBS` | INT ≥ 1 | 2000 (ceiling 50 000) | SAP job monitor | Jobs read per run and kind (cancelled, finished of watched programs, active, waiting; resolver candidates) |
| `JOB_MAX_LOG_READS` | INT ≥ 0 | 50 (ceiling 500) | SAP job monitor | Job logs read per run (detection, resolvers, evidence); over budget the watermark waits |
| `JOB_MAX_MESSAGES` | INT ≥ 0 | 20 | SAP job monitor | Error / abort lines of a job log kept per job |
| `JOB_MAX_DEPTH` | INT ≥ 1 | 3 (ceiling 10) | SAP job monitor | Ancestors followed upwards from a failed job |
| `JOB_MAX_CHILDREN` | INT ≥ 0 | 50 | SAP job monitor | Children of a failing job's parent kept as context |
| `JOB_MAX_APPLOGS` | INT ≥ 0 | 20 | SAP job monitor | Application logs linked per failed job |
| `JOB_EXCLUDE_PCRE` | LIST (PCRE) | — | SAP job monitor | Job names never reported (complete name, case ignored); an invalid pattern is a `JOB_CONFIG_INVALID` finding |
| `JOB_LOG_PROGRAMS` | LIST | — | SAP job monitor | Programs (exact names) whose finished jobs get their job log checked for error lines (`JOB_LOG_ERROR`) |
| `JOB_LOG_ERROR_TYPES` | LIST | E,A,X | SAP job monitor | Message types of a job log line that count as an error |
| `JOB_LONG_RUNNING_MIN` | INT ≥ 1 | 240 | SAP job monitor | Minutes active before a job is long-running |
| `JOB_NOT_STARTED_MIN` | INT ≥ 1 | 30 | SAP job monitor | Minutes after the planned start a waiting job may wait |
| `JOB_WAITING_STATUSES` | LIST | S,Y | SAP job monitor | TBTCO statuses of a job waiting to start |
| `JOB_RESOLVERS` | LIST (classes, `ZIF_CA_OPS_JOB_RESOLVER`) | `ZCL_CA_OPS_JOB_RES_EVENT,ZCL_CA_OPS_JOB_RES_HEUR` | SAP job monitor | Parent / child resolvers in order (FIELD and JOBLOG after V62, a consumer's resolver before the heuristic) |
| `JOB_ENRICHERS` | LIST (classes, `ZIF_CA_OPS_JOB_ENRICHER`) | — | SAP job monitor | Business context of a consumer, in order |
| `JOB_CLAIMS` | LIST (classes, `ZIF_CA_OPS_JOB_CLAIM`) | — | SAP job monitor | Monitors that already report a job's own failure (information finding only) |
| `JOB_PARENT_FIELDS` | LIST (two TBTCO fields) | — | resolver FIELD | Parent job name and count fields; checked against the runtime DDIC of TBTCO (V62) |
| `JOB_EVENT_IDS` | LIST | SAP_END_OF_JOB | resolver EVENT | Events whose parameter is the predecessor's job name (32) + count (8) (V61) |
| `JOB_CHILD_MSG_IDS` | LIST (`MSGID/MSGNO`) | — | resolver JOBLOG | Job log messages that announce a released job (V62) |
| `JOB_CHILD_MSG_PCRE` | CHAR (PCRE) | — | resolver JOBLOG | Pattern of such a line: group 1 job name, group 2 job count |
| `JOB_PARENT_PROGRAMS` | LIST | — | resolvers JOBLOG, HEURISTIC | Programs (exact) of the jobs that may start children (blank = any) |
| `RETENTION_DAYS_JOB_EVIDENCE` | INT | 180 | purge target `JOB_EVIDENCE` (`ZCL_CA_OPS_JOB_PURGE`) | Evidence of the SAP job monitor (at least 30 applied) |
| `METRIC_TIME_ZONE` | CHAR (TTZZ zone) | UTC | metrics CDS (`ZI_CA_OpsMetricTz`) | Time zone of the month and week of the response-time metrics |
| `PURGE_PACKAGE_SIZE` | INT ≥ 1 | 1000 | `ZCL_CA_OPS_PURGE` | Rows deleted per package (one commit per package) |
| `RETENTION_DAYS_RUN` | INT | 400 | purge | Runs with findings and exception history (at least 30 applied) |
| `RETENTION_DAYS_ALERT_LOG` | INT | 180 | purge | Alert log (at least 30 applied) |
| `RETENTION_DAYS_REVIEW` | INT | 400 | purge | Sign-offs of the daily control review (at least 30 applied) |
| `SHIFT_TIME_ZONE` | CHAR (TTZZ zone) | UTC | shift handover CDS (`ZI_CA_OpsShiftTz`) | Time zone of the shift start times |
| `SHIFT_TIMES_DEFAULT` | kind S, TIME rows (`HHMMSS`) | 000000 | shift handover CDS (`ZI_CA_OpsShiftDef`) | Shift start times of teams without `SHIFT_TIMES_<team>` and of exceptions of no team (one row per start) |
| `SLA_DAYS_DEFAULT` | INT ≥ 0 | 1 | `ZCL_CA_OPS_STORE` | SLA days of an exception when `SLA_DAYS_<area>_<severity>` is blank |

**Names a consumer completes and delivers** (definitions in area `CA_OPS`, in the consumer's seed files):

| Name | Read by | Example (fictitious consumer, prefix `XX`) |
|---|---|---|
| `ALERT_<route>` | `SEND( iv_route )` | `ALERT_DAILY` |
| `SLA_DAYS_<area>_<B / E / W>` | store (due date of a new exception) | `SLA_DAYS_XX_BANK_E` |
| `RETENTION_DAYS_<target>` (any name: the registry row names area and parameter) | purge (`ZCA_OPS_PURGE`) | `RETENTION_DAYS_FILE_EVENT` |
| `SHIFT_TIMES_<team>` (kind S, value type TIME, one row per shift start `HHMMSS`, local time of `SHIFT_TIME_ZONE`) | shift handover CDS (`ZI_CA_OpsShiftDef`, read in CDS like `CONTROL_TIME_ZONE`) | `SHIFT_TIMES_ONSITE` = 060000, 140000, 220000 (2026-11-11; the team = a value of `CONTROL_TEAMS`) |
| `CHECK_STALE_MIN_<area>` (INT ≥ 1, minutes) | area dashboard CDS (`ZI_CA_OpsChkStaleA`, read in CDS like `CONTROL_TIME_ZONE`) | `CHECK_STALE_MIN_XX_COLL` (with the example process of `ADDING_A_BUSINESS_PROCESS.md` §10, on activation) |

Values (landscape-specific, e.g. recipient lists, the section class) are value rows of the framework
app `ZUI_CA_PARAM_O4`; definitions travel only by transport.

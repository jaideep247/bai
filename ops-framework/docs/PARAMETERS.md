# Parameters of the operations framework (ZCA_PARAM area CA_OPS)

> **First principle:** the framework reads only its own area; a consumer adds names, never logic.
> **Analogy:** a shared switchboard with labelled sockets — the framework wires a few, each tenant labels its own.

Area `CA_OPS` (`config/param_areas.csv`); definitions `config/param_definitions.csv`, generated into
`ZCL_CA_OPS_PARAM_SEED` by `tools/param_definitions.py` (check `param_definitions` of `tools/checks.py`).
Read through `ZCL_CA_OPS_FACTORY=>GET_PARAMS( )`: a name with prefix `ALERT_`, `SLA_`, `RETENTION_` or
`PURGE_`, `CONTROL_` or `EXC_` is read in `CA_OPS`; a value the framework resolves (maintained value or definition default)
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
| `CONTROL_TIME_ZONE` | CHAR (TTZZ zone) | UTC | control review CDS (`ZI_CA_OpsCtlTz`) | Time zone of the business date of a control, of its review cut-off and of the sign-off time shown (a consumer delivers its value row, e.g. `CST`) |
| `CONTROL_TEAMS` | LIST | ONSITE,OFFSHORE | `ZCL_CA_OPS_CFG_CHECKS=>TEAM_VALID` | Teams a control may name (control register, checked on save) |
| `EXC_REASON_CODES` | LIST | TIMING,INVESTIGATING | exceptions app (action *Classify*) | Reason codes an open exception may be classified with |
| `PURGE_PACKAGE_SIZE` | INT ≥ 1 | 1000 | `ZCL_CA_OPS_PURGE` | Rows deleted per package (one commit per package) |
| `RETENTION_DAYS_RUN` | INT | 400 | purge | Runs with findings and exception history (at least 30 applied) |
| `RETENTION_DAYS_ALERT_LOG` | INT | 180 | purge | Alert log (at least 30 applied) |
| `RETENTION_DAYS_REVIEW` | INT | 400 | purge | Sign-offs of the daily control review (at least 30 applied) |
| `SLA_DAYS_DEFAULT` | INT ≥ 0 | 1 | `ZCL_CA_OPS_STORE` | SLA days of an exception when `SLA_DAYS_<area>_<severity>` is blank |

**Names a consumer completes and delivers** (definitions in area `CA_OPS`, in the consumer's seed files):

| Name | Read by | Example (payment engine suite) |
|---|---|---|
| `ALERT_<route>` | `SEND( iv_route )` | `ALERT_MORNING` |
| `SLA_DAYS_<area>_<B / E / W>` | store (due date of a new exception) | `SLA_DAYS_CD_EBS_E` |
| `RETENTION_DAYS_<target>` (any name: the registry row names area and parameter) | purge (`ZCA_OPS_PURGE`) | `RETENTION_DAYS_FMON_EVENT` |

Values (landscape-specific, e.g. recipient lists, the section class) are value rows of the framework
app `ZUI_CA_PARAM_O4`; definitions travel only by transport.

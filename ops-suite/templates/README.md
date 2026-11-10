# E-mail templates of the operations suite (documented sources)

> User decisions 2026-11-10: every alert e-mail is an editable SAP e-mail template (SMTG), changed in DV1 and
> transported only; amounts only where the rule shows them (`SHOW_AMOUNTS`, default off; on for the missing
> bank ACK alert). Mechanism: `ops-framework/docs/ALERT_TEMPLATES.md`; review of every alert:
> `docs/ALERT_CONTEXT_REVIEW.md`.

| Template | Used by | Priority | Amounts |
|---|---|---|---|
| `ZCD_OPS_ALERT_EBS_BLOCK` | `EBS_BLOCK` (CD_EBS, B) | P1 - 15 min, 24x7 | no |
| `ZCD_OPS_ALERT_EBS` | `EBS_ERROR` (CD_EBS, E, amber run, abort) | P2 - 1 h in business hours | no |
| `ZCD_OPS_ALERT_ACK` | `FMON_ACK` (proposed) and every rule that selects ACK findings without a template of its own (section `ZCL_CD_OPS_ACK_MAIL`, `GC_ACK_TEMPLATE`) | P2 - 1 h in business hours | **yes** |
| `ZCD_OPS_ALERT_FMON_SLA` | `FMON_SLA` (CD_FMON, E) | P2 - 1 h in business hours | no |
| `ZCD_OPS_ALERT_FMON_FILE` | `FMON_FILE` (proposed: missing, rejected, failed, duplicate, size, PRISM failed) | P2 - 1 h in business hours | no |
| `ZCD_OPS_ALERT_RETURNS` | `FMON_PART` (CD_FMON, E; pattern corrected to the lot checks - proposed) | P2 - 1 h in business hours | no |
| `ZCD_OPS_ALERT_DEADLINE` | `FMON_BAIDL` (CD_FMON, E, STAGE_DEADLINE_MISSED) | P2 - 1 h in business hours | no |
| `ZCD_OPS_ALERT_NOC` | `NOC_AGING` (CD_FMON, E) | P2 - 1 h in business hours | no |
| `ZCD_OPS_ALERT_REGEN` | `FMON_REGEN` (CD_FMON, E / B) | P1 - 15 min, 24x7 | no |
| `ZCD_OPS_ALERT_HCK` | `HCK_RED` (CD_HCK, E, red run, abort) | P2 - 1 h in business hours | no |
| `ZCD_OPS_ALERT_RECON` | `HCK_RECON` (CD_HCK, E) | P2 - 1 h in business hours | no |
| `ZCD_OPS_ALERT_ABORT` | `ALL_ABORT` (every area, B, on abort) | P1 - 15 min, 24x7 | no |
| `ZCD_OPS_ALERT_LOCKED` | `RUN_LOCKED` (every area, E) | P2 - 1 h in business hours | no |
| `ZCD_OPS_MORNING_REPORT` | morning report (`HCK_MAIL_TEMPLATE`) | report | as in the report |

Each page holds ID, description, data source, subject, HTML body, text body, placeholders and the DV1
creation steps. abapGit support for object type SMTG is not verified (VERIFY-ADT V22 of the framework):
the pages are the delivery; once created in DV1 a template can be pulled into the repository by abapGit if
the DV1 version serializes SMTG. A rule without `TEMPLATE_ID` uses the channel default, else the framework's
generic template `ZCA_OPS_ALERT_DEFAULT`; when SMTG cannot be used the built-in layout is sent with the same
content and the alert log row names the reason.

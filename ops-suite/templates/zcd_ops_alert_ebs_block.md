# E-mail template ZCD_OPS_ALERT_EBS_BLOCK

> Documented source of an SAP e-mail template (object type SMTG) of the payment engine operations suite
> (2026-11-10). abapGit support for SMTG is not verified (VERIFY-ADT V22): the template is created in DV1
> from this page and transported. Layout and placeholders follow the framework's generic template
> `ZCA_OPS_ALERT_DEFAULT`; this one adds the business heading, the impact and what to do.

| Attribute | Value |
|---|---|
| Template ID | `ZCD_OPS_ALERT_EBS_BLOCK` |
| Description | Ops suite: EBS blocked bank lines |
| Package | `ZCD_OPS` |
| Data source | `ZI_CA_OPS_ALERTMAILCTX` (framework; key `ALERT_ID`) |
| Used by | `EBS_BLOCK` (CD_EBS, B) |
| Priority | P1 - 15 min, 24x7 |
| Amounts shown | no (open decision; set SHOW_AMOUNTS on the rule to show them) |
| Business context in the tables | company code, account (house bank / account ID or masked), business date (booking / statement date), payment method of the line |

## Subject

```
{{SUBJECT}}
```

The impact-first subject of the code: `[SYSID][AREA][severity] <check or rule>: <n> finding(s)` (amounts per currency only with `SHOW_AMOUNTS`); a single finding: rule and its text.

## HTML body

```html
<p><b>{{SUBJECT}}</b></p>
<p><b>Blocked bank statement lines - money must not move.</b> Bank statement lines were blocked (severity B): they are not posted until the cause is cleared.</p>
<p>{{RUN_LINE}}<br>{{REFERENCE_LINE}}</p>
<table cellpadding="2">
  <tr><td><b>Area</b></td><td>{{AREA}} {{AREA_TEXT}}</td></tr>
  <tr><td><b>Alert rule</b></td><td>{{RULE_ID}}</td></tr>
  <tr><td><b>Severity</b></td><td>{{SEVERITY}} {{SEVERITY_TEXT}}</td></tr>
  <tr><td><b>Check</b></td><td>{{CHECK_CODE}}</td></tr>
  <tr><td><b>Findings</b></td><td>{{FINDINGS_TOTAL}} (new {{FINDINGS_NEW}}, repeated {{FINDINGS_REPEATED}}, overdue {{FINDINGS_OVERDUE}})</td></tr>
  <tr><td><b>Not listed (above the limit)</b></td><td>{{FINDINGS_HELD_BACK}}</td></tr>
  <tr><td><b>Due date / owner</b></td><td>{{DUE_DATE}} {{OWNER}}</td></tr>
  <tr><td><b>Run started / ended</b></td><td>{{STARTED_AT}} / {{ENDED_AT}}</td></tr>
  <tr><td><b>Exceptions app</b></td><td>{{EXCEPTIONS_LINK}}</td></tr>
</table>
<p><b>What to do</b></p>
<ul>
  <li>Open the exceptions app (link below), area CD_EBS, and work the blocked lines first.</li>
  <li>Check the bank transaction code mapping and the posting rule of each line (EBS validation dashboard).</li>
  <li>Escalation: the RTB lead list is added after 3 alerting runs in a row.</li>
</ul>
{{TABLE_SECTION}}
{{TABLE_MAIN}}
```

## Text body

```
{{SUBJECT}}
Blocked bank statement lines - money must not move. Bank statement lines were blocked (severity B): they are not posted until the cause is cleared.
{{REFERENCE_LINE}}
Area: {{AREA}} {{AREA_TEXT}}
Alert rule: {{RULE_ID}}
Severity: {{SEVERITY}} {{SEVERITY_TEXT}}
Check: {{CHECK_CODE}}
Findings: {{FINDINGS_TOTAL}} (new {{FINDINGS_NEW}}, repeated {{FINDINGS_REPEATED}}, overdue {{FINDINGS_OVERDUE}})
Not listed (above the limit): {{FINDINGS_HELD_BACK}}
Due date / owner: {{DUE_DATE}} {{OWNER}}
Run started / ended: {{STARTED_AT}} / {{ENDED_AT}}
Exceptions app: {{EXCEPTIONS_LINK}}
What to do:
- Open the exceptions app (link below), area CD_EBS, and work the blocked lines first.
- Check the bank transaction code mapping and the posting rule of each line (EBS validation dashboard).
- Escalation: the RTB lead list is added after 3 alerting runs in a row.
{{TABLE_SECTION}}
{{TABLE_MAIN}}
```

## Placeholders

Standard context keys of the framework (`ops-framework/docs/ALERT_TEMPLATES.md` section 3), plain text;
a key not known for a message is blank. `{{TABLE_SECTION}}` / `{{TABLE_MAIN}}` mark where the code puts
its tables (escaped cells); a template without them gets the tables appended and the alert log row says so.

## DV1 creation steps

1. Activate the framework data source `ZI_CA_OPS_ALERTMAILCTX` and the generic template first
   (`ops-framework/templates/zca_ops_alert_default.md`).
2. ADT *New > E-mail Template* (or Fiori *Maintain Email Templates*): ID and description above, package
   `ZCD_OPS`, data source `ZI_CA_OPS_ALERTMAILCTX`; paste subject, HTML and text; activate (VERIFY-ADT:
   placeholder syntax `{{NAME}}`, `ops-framework/docs/ALERT_TEMPLATES.md` V17-V25).
3. Set `TEMPLATE_ID` of the rule(s) above in `ZUI_CA_OPS_CFG` (customizing request, `config/alert_seed.md`).
4. QA1: trigger the rule once; `ZCA_OPS_ALLOG` shows the template, `RENDERER` = `SMTG`, no `RENDER_INFO`.
5. Transport DV1 -> QA1 -> PS4 with the suite. Never edited in PS4 (user decision 2026-11-10).

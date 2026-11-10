# E-mail template ZCD_OPS_ALERT_FMON_FILE

> Documented source of an SAP e-mail template (object type SMTG) of the payment engine operations suite
> (2026-11-10). abapGit support for SMTG is not verified (VERIFY-ADT V22): the template is created in DV1
> from this page and transported. Layout and placeholders follow the framework's generic template
> `ZCA_OPS_ALERT_DEFAULT`; this one adds the business heading, the impact and what to do.

| Attribute | Value |
|---|---|
| Template ID | `ZCD_OPS_ALERT_FMON_FILE` |
| Description | Ops suite: payment file failures |
| Package | `ZCD_OPS` |
| Data source | `ZI_CA_OPS_ALERTMAILCTX` (framework; key `ALERT_ID`) |
| Used by | `FMON_FILE` (proposed: missing, rejected, failed, duplicate, size, PRISM failed) |
| Priority | P2 - 1 h in business hours |
| Amounts shown | no (open decision) |
| Business context in the tables | business date, payment method, record count of the file |

## Subject

```
{{SUBJECT}}
```

The impact-first subject of the code: `[SYSID][AREA][severity] <check or rule>: <n> finding(s)` (amounts per currency only with `SHOW_AMOUNTS`); a single finding: rule and its text.

## HTML body

```html
<p><b>{{SUBJECT}}</b></p>
<p><b>Payment file failed, rejected or missing.</b> A payment file is missing, was rejected by the bank (NACK), failed in processing, is a duplicate or has an unexpected size.</p>
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
  <li>Open the file in the file monitoring dashboard; a NACK names the rejected records.</li>
  <li>A duplicate or regenerated file: confirm with payment operations before anything is re-sent.</li>
</ul>
{{TABLE_SECTION}}
{{TABLE_MAIN}}
```

## Text body

```
{{SUBJECT}}
Payment file failed, rejected or missing. A payment file is missing, was rejected by the bank (NACK), failed in processing, is a duplicate or has an unexpected size.
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
- Open the file in the file monitoring dashboard; a NACK names the rejected records.
- A duplicate or regenerated file: confirm with payment operations before anything is re-sent.
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

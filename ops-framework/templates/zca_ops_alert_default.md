# E-mail template ZCA_OPS_ALERT_DEFAULT — generic alert e-mail of the framework

> Delivered as a documented source (abapGit support for object type SMTG is not verified - VERIFY-ADT,
> `docs/ALERT_TEMPLATES.md` section 5). Created once in DV1 with the steps below, transported
> development -> quality -> production (DV1 -> QA1 -> production; never edited in production).

| Attribute | Value |
|---|---|
| Template ID | `ZCA_OPS_ALERT_DEFAULT` (parameter `ALERT_TEMPLATE_DEFAULT`, area `CA_OPS`) |
| Description | Ops framework: generic alert e-mail |
| Package | `ZCA_OPS` |
| Data source | CDS view entity `ZI_CA_OPS_ALERTMAILCTX` (key `ALERT_ID`) |
| Used by | every alert rule and channel without a template of its own; fallback of a consumer's template when the rule names none |
| Language | EN (translate in the template editor; the router renders in the logon language of the job user) |

## Subject

```
{{SUBJECT}}
```

`SUBJECT` is the impact-first subject the code builds: `[SYSID][AREA][severity] <what> : <how many / how much>`
(`[PRD][ZPE_OPS][E] AMOUNT_MISMATCH: 12 finding(s)`; with `SHOW_AMOUNTS` on the rule `, USD 1,234.00`; a consumer
section may name its own). The built-in layout uses the same subject.

## HTML body

```html
<p><b>{{SUBJECT}}</b></p>
<p>{{RUN_LINE}}</p>
<p>{{REFERENCE_LINE}}</p>
<table cellpadding="2">
  <tr><td><b>Area</b></td><td>{{AREA}} {{AREA_TEXT}}</td></tr>
  <tr><td><b>Alert rule</b></td><td>{{RULE_ID}}</td></tr>
  <tr><td><b>Severity</b></td><td>{{SEVERITY}} {{SEVERITY_TEXT}}</td></tr>
  <tr><td><b>Check</b></td><td>{{CHECK_CODE}}</td></tr>
  <tr><td><b>Findings</b></td><td>{{FINDINGS_TOTAL}} (new {{FINDINGS_NEW}}, repeated {{FINDINGS_REPEATED}}, overdue {{FINDINGS_OVERDUE}})</td></tr>
  <tr><td><b>Not listed (above the limit)</b></td><td>{{FINDINGS_HELD_BACK}}</td></tr>
  <tr><td><b>Due date</b></td><td>{{DUE_DATE}} {{OWNER}}</td></tr>
  <tr><td><b>Run started</b></td><td>{{STARTED_AT}}</td></tr>
  <tr><td><b>Run ended</b></td><td>{{ENDED_AT}}</td></tr>
  <tr><td><b>Amount total</b></td><td>{{AMOUNT_TOTAL}}</td></tr>
  <tr><td><b>Exceptions app</b></td><td>{{EXCEPTIONS_LINK}}</td></tr>
</table>
{{TABLE_SECTION}}
{{TABLE_MAIN}}
```

## Text body

```
{{SUBJECT}}
{{REFERENCE_LINE}}
Area: {{AREA}} {{AREA_TEXT}}
Alert rule: {{RULE_ID}}
Severity: {{SEVERITY}} {{SEVERITY_TEXT}}
Check: {{CHECK_CODE}}
Findings: {{FINDINGS_TOTAL}} (new {{FINDINGS_NEW}}, repeated {{FINDINGS_REPEATED}}, overdue {{FINDINGS_OVERDUE}})
Due date: {{DUE_DATE}} {{OWNER}}
Run started: {{STARTED_AT}} / ended: {{ENDED_AT}}
Exceptions app: {{EXCEPTIONS_LINK}}
{{TABLE_SECTION}}
{{TABLE_MAIN}}
```

## Placeholders

Every placeholder is a standard context key (`ZIF_CA_OPS_TYPES=>TY_MAIL_HEADER`, element of
`ZI_CA_OPS_ALERTMAILCTX`), plain text only; a key that is not known for a message is blank and the
template does not break. `TABLE_SECTION` and `TABLE_MAIN` are markers: their value is a plain token
(letters and digits) the code replaces after rendering by its HTML table (HTML body) and text table (text
body), so the cells are escaped by the code whatever the template engine does. A customised template
without one of them still gets the table, appended at the end; the alert log row records it (message 073).
The full key list with meaning: `docs/ALERT_TEMPLATES.md` section 3.

The built-in layout (`ZCL_CA_OPS_MAIL_TPL_BUILTIN`) renders the same content without SMTG; differences: a
key that is blank is left out (no empty label) and the labels are text symbols of that class.

## DV1 creation steps

1. ADT: *New > Other ABAP Repository Object > E-mail Template* (or the Fiori app *Maintain Email
   Templates*), ID `ZCA_OPS_ALERT_DEFAULT`, package `ZCA_OPS`, workbench request of the framework.
2. Data source: `ZI_CA_OPS_ALERTMAILCTX` (activate the view first). VERIFY-ADT: the editor offers the
   elements in upper case as placeholders `{{NAME}}`; if the syntax differs, keep the names and adapt
   the braces only.
3. Paste subject, HTML body and text body as above; save, activate.
4. Check: run the demo report `ZCA_OPS_DEMO` (test mode off, *Sample*) with a rule on channel EMAIL, or any
   consumer alert in DV1; the alert log row (`ZCA_OPS_ALLOG`) shows `TEMPLATE_ID` = `ZCA_OPS_ALERT_DEFAULT`,
   `RENDERER` = `SMTG` and no `RENDER_INFO`. With the template deleted or inactive the e-mail still goes
   out in the built-in layout and `RENDER_INFO` names the template (071).
5. Transport with the framework (DV1 -> QA1 -> production). Changes later: only in DV1, by transport.

# E-mail template ZCD_OPS_MORNING_REPORT

> Documented source of an SAP e-mail template (object type SMTG) of the payment engine operations suite
> (2026-11-10). abapGit support for SMTG is not verified (VERIFY-ADT V22): created in DV1 from this page
> and transported.

| Attribute | Value |
|---|---|
| Template ID | `ZCD_OPS_MORNING_REPORT` (parameter `HCK_MAIL_TEMPLATE`, area `CD_HCK`) |
| Description | Ops suite: morning report |
| Package | `ZCD_OPS` |
| Data source | `ZI_CA_OPS_ALERTMAILCTX` (framework) |
| Used by | `ZCD_MORNING_REPORT` -> `ZIF_CA_OPS_ALERT=>SEND( iv_route = HCK_MAIL_ROUTE, iv_template_id = HCK_MAIL_TEMPLATE )` |
| Amounts shown | as in the report (`ZCL_CD_HCK_REPORT_HTML`); the template adds none |

The morning report is a prepared report: its HTML (`ZCL_CD_HCK_REPORT_HTML=>RENDER`) is the block
`TABLE_MAIN`, its subject the key `SUBJECT`. Only `SUBJECT`, `SYSTEM_ID`, `CLIENT`, `RULE_ID` (the route),
`TIME_ZONE` and `EXCEPTIONS_LINK` are filled for a report; the other keys are blank.

## Subject

```
{{SUBJECT}}
```

## HTML body

```html
<p>{{SYSTEM_ID}} / {{CLIENT}} - payment engine morning report. Exceptions app: {{EXCEPTIONS_LINK}}</p>
{{TABLE_MAIN}}
```

## Text body

```
{{SUBJECT}}
{{TABLE_MAIN}}
```

## DV1 creation steps

1. Activate the framework data source `ZI_CA_OPS_ALERTMAILCTX` and the generic template first
   (`ops-framework/templates/zca_ops_alert_default.md`).
2. ADT *New > E-mail Template* (or Fiori *Maintain Email Templates*): ID and description above, package
   `ZCD_OPS`, data source `ZI_CA_OPS_ALERTMAILCTX`; paste subject, HTML and text; activate (VERIFY-ADT:
   placeholder syntax `{{NAME}}`, `ops-framework/docs/ALERT_TEMPLATES.md` V17-V25).
3. Parameter `HCK_MAIL_TEMPLATE` (area `CD_HCK`) holds this ID by its definition default; a value row only to use another template.
4. QA1: run `ZCD_MORNING_REPORT` with e-mail; `ZCA_OPS_ALLOG` shows the template, `RENDERER` = `SMTG`, no `RENDER_INFO`.
5. Transport DV1 -> QA1 -> PS4 with the suite. Never edited in PS4 (user decision 2026-11-10).

// Data source of the alert e-mail templates (SAP e-mail templates, object type SMTG; 2026-11-10).
// Its elements are the standard context keys of ZIF_CA_OPS_TYPES=>TY_MAIL_HEADER with the same
// names: they are the placeholder catalogue of every template (ZCA_OPS_ALERT_DEFAULT and the
// consumers' templates). Preferred rendering passes the keys from code (RENDER_W_DATA, VERIFY-ADT);
// rendering by key (RENDER with ALERT_ID) reads this view: the keys stored with the alert log row
// and its run are filled, the others are blank (filled only by RENDER_W_DATA). Table blocks are
// never data: the code puts its tables where the template has TABLE_MAIN / TABLE_SECTION.
// No authorization check: alert metadata for the template engine only (no business data).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Alert e-mail context (template data source)'
define view entity ZI_CA_OPS_ALERTMAILCTX
  as select from    zca_ops_allog  as Log
    left outer join zca_ops_run    as Run  on Run.run_id = Log.run_id
    left outer join zca_param_area as Area on Area.area = Log.area
{
  key Log.alert_id                            as ALERT_ID,
      Log.subject                             as SUBJECT,
      cast( ' ' as abap.char(255) )           as HEADLINE,
      Run.sysid                               as SYSTEM_ID,
      $session.client                         as CLIENT,
      Log.area                                as AREA,
      Area.description                        as AREA_TEXT,
      Log.rule_id                             as RULE_ID,
      cast( ' ' as abap.char(1) )             as SEVERITY,
      cast( ' ' as abap.char(20) )            as SEVERITY_TEXT,
      cast( ' ' as abap.char(30) )            as CHECK_CODE,
      cast( ' ' as abap.char(255) )           as CHECK_TEXT,
      Log.run_id                              as RUN_ID,
      Run.variant                             as RUN_VARIANT,
      Run.status                              as RUN_STATUS,
      Run.rag                                 as RUN_RAG,
      cast( ' ' as abap.char(255) )           as RUN_LINE,
      Run.jobname                             as JOB_NAME,
      Run.jobcount                            as JOB_COUNT,
      Run.started_at                          as STARTED_AT,
      Run.ended_at                            as ENDED_AT,
      cast( ' ' as abap.char(6) )             as TIME_ZONE,
      Run.finding_count                       as FINDINGS_TOTAL,
      cast( ' ' as abap.char(10) )            as FINDINGS_NEW,
      cast( ' ' as abap.char(10) )            as FINDINGS_REPEATED,
      cast( ' ' as abap.char(10) )            as FINDINGS_OVERDUE,
      cast( ' ' as abap.char(10) )            as FINDINGS_HELD_BACK,
      cast( ' ' as abap.char(10) )            as DUE_DATE,
      cast( ' ' as abap.char(12) )            as OWNER,
      cast( ' ' as abap.char(255) )           as EXCEPTIONS_LINK,
      cast( ' ' as abap.char(255) )           as REFERENCE_LINE,
      cast( ' ' as abap.char(255) )           as AMOUNT_TOTAL,
      cast( ' ' as abap.char(80) )            as TABLE_MAIN,
      cast( ' ' as abap.char(80) )            as TABLE_SECTION,
      Log.template_id                         as TEMPLATE_ID
}

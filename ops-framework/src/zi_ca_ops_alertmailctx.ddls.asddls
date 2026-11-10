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
  key Log.alert_id                            as alert_id,
      Log.subject                             as subject,
      cast( ' ' as abap.char(255) )           as headline,
      Run.sysid                               as system_id,
      $session.client                         as client,
      Log.area                                as area,
      Area.description                        as area_text,
      Log.rule_id                             as rule_id,
      cast( ' ' as abap.char(1) )             as severity,
      cast( ' ' as abap.char(20) )            as severity_text,
      cast( ' ' as abap.char(30) )            as check_code,
      cast( ' ' as abap.char(255) )           as check_text,
      Log.run_id                              as run_id,
      Run.variant                             as run_variant,
      Run.status                              as run_status,
      Run.rag                                 as run_rag,
      cast( ' ' as abap.char(255) )           as run_line,
      Run.jobname                             as job_name,
      Run.jobcount                            as job_count,
      Run.started_at                          as started_at,
      Run.ended_at                            as ended_at,
      cast( ' ' as abap.char(6) )             as time_zone,
      Run.finding_count                       as findings_total,
      cast( ' ' as abap.char(10) )            as findings_new,
      cast( ' ' as abap.char(10) )            as findings_repeated,
      cast( ' ' as abap.char(10) )            as findings_overdue,
      cast( ' ' as abap.char(10) )            as findings_held_back,
      cast( ' ' as abap.char(10) )            as due_date,
      cast( ' ' as abap.char(12) )            as owner,
      cast( ' ' as abap.char(255) )           as exceptions_link,
      cast( ' ' as abap.char(255) )           as reference_line,
      cast( ' ' as abap.char(255) )           as amount_total,
      cast( ' ' as abap.char(80) )            as table_main,
      cast( ' ' as abap.char(80) )            as table_section,
      Log.template_id                         as template_id
}

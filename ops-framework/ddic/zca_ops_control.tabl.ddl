@EndUserText.label : 'Ops framework: control register (daily review)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zca_ops_control {
  key mandt     : abap.clnt not null;
  // Area of the control (a parameter area of ZCA_PARAM; authorisation ZCA_OPS per area)
  key area      : zca_param_area_id not null;
  key control_id : abap.char(20) not null;
  // Display name (the language-dependent guidance is ZCA_OPS_CTLT)
  description   : abap.char(60);
  // Category shown with the control (free text of the consumer, e.g. a business process)
  category      : abap.char(30);
  // Owner and backup (SAP users, checked on save) and their team (values: parameter CONTROL_TEAMS)
  owner         : syuname;
  backup        : syuname;
  team          : abap.char(10);
  // Review cut-off on the business date, local time of the parameter CONTROL_TIME_ZONE (initial = end of day)
  cutoff_time   : abap.tims;
  // Optional link to the runbook of the control (http / https, checked on save)
  runbook_url   : abap.char(255);
  active        : abap_boolean;
  seq           : abap.int4;
  // RAP configuration app: set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}
// The checks a control covers: ZCA_OPS_CTLCHK. Its status per business date is derived from the findings
// (ZI_CA_OpsCtlFindDay), never stored; the daily sign-off is ZCA_OPS_REVIEW. New rows only by transport (DV1).

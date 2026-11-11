@EndUserText.label : 'Ops framework: business process register'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zca_ops_proc {
  key mandt     : abap.clnt not null;
  // Area of the process (a parameter area of ZCA_PARAM): runs, findings, alert rules, controls and the
  // authorisation ZCA_OPS of the process name it (one area register)
  key area      : zca_param_area_id not null;
  key process_id : abap.char(20) not null;
  description   : abap.char(60);
  // Owner and backup of the process (SAP users, checked on save; the onboarding check reports a gap)
  owner         : syuname;
  backup        : syuname;
  // Optional link to the runbook of the process (http / https, checked on save)
  runbook_url   : abap.char(255);
  // PFCG role that grants ZCA_OPS for the area (03 display, 02 operator, 16 job user); blank = the
  // authorisation of the process is not covered (onboarding check)
  auth_role     : abap.char(30);
  // X = the process writes own tables besides the findings: a purge target is required
  own_data      : abap_boolean;
  // Purge target of the own tables (ZCA_OPS_PURGE); blank with OWN_DATA blank = findings only, purged with
  // their runs (built-in target RUN)
  purge_target  : abap.char(12);
  // Process of the process catalogue this business process monitors (ZCA_OPS_CATPRC, 2026-11-11); blank = not
  // in the catalogue. The process and its checks are in effect only while that catalogue process is active (a
  // name that is not in the catalogue does not stop them; the onboarding check reports it)
  cat_process   : abap.char(20);
  active        : abap_boolean;
  seq           : abap.int4;
  // RAP configuration app: set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}
// The checks of a process: ZCA_OPS_CHECK (PROCESS_ID). Read by ZCL_CA_OPS_CHECK_DAO (onboarding check) and the
// area dashboard ZR_CA_OpsCheckStatus. New rows only by transport (DV1).

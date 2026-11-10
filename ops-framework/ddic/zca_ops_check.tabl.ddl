@EndUserText.label : 'Ops framework: check registry'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zca_ops_check {
  key mandt     : abap.clnt not null;
  // Area of the run and of the findings (a parameter area of ZCA_PARAM)
  key area      : zca_param_area_id not null;
  // Check ID = GROUP2 of every finding of the check (control register, alert rules, dashboard)
  key check_id  : abap.char(20) not null;
  // Business process of the check (ZCA_OPS_PROC); blank = a technical check of the area
  process_id    : abap.char(20);
  description   : abap.char(60);
  // Implements ZIF_CA_OPS_CHECK (checked on save); ZCL_CA_OPS_CHK_AGG = the no-code aggregate check
  class_name    : seoclsname;
  // Schedule group: one run of the area per group (run variant of ZCA_OPS_RUN, job of ZCA_OPS_CHECK_RUN)
  sched_group   : abap.char(10);
  // X = the check reports per company code (its findings carry BUKRS; an aggregate row needs BUKRS_FIELD)
  bukrs_aware   : abap_boolean;
  active        : abap_boolean;
  seq           : abap.int4;
  // RAP configuration app: set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}
// Read by ZCL_CA_OPS_CHECK_DAO=>GET_CHECKS (area, schedule group, active); new rows only by transport (DV1)

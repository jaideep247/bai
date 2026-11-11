@EndUserText.label : 'Ops framework: process catalogue steps'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zca_ops_catstp {
  key mandt      : abap.clnt not null;
  key process_id : abap.char(20) not null;
  // Order of the step in the process (010, 020, ...)
  key step_no    : abap.numc(3) not null;
  // T transaction, P program (report), M mass activity type, J background job (name pattern), E event / BAdI
  step_kind      : abap.char(1);
  // SAP standard object of the step (transaction code, program, mass activity type, ...)
  obj_name       : abap.char(40);
  description    : abap.char(60);
  // C confirmed, V VERIFY (VERIFY_REF names the item)
  evidence       : abap.char(1);
  verify_ref     : abap.char(20);
  // RAP configuration app: set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}
// Read by ZCL_CA_OPS_CAT_DAO; a test tool reads process -> steps through its catalogue adapter (PROCESS_CATALOGUE.md)

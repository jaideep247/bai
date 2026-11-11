@EndUserText.label : 'Ops framework: process catalogue tables'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zca_ops_cattab {
  key mandt      : abap.clnt not null;
  key process_id : abap.char(20) not null;
  // SAP standard table of the process (checked on save against the runtime DDIC)
  key tabname    : abap.char(30) not null;
  // H header, I item, L log / history, S status, C configuration
  tab_role       : abap.char(1);
  // Business object of the link registry on this table (ZCA_OPS_LNKOBJ), blank = none yet
  link_object    : abap.char(30);
  description    : abap.char(60);
  // C confirmed, V VERIFY (VERIFY_REF names the item)
  evidence       : abap.char(1);
  verify_ref     : abap.char(20);
  // RAP configuration app: set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}

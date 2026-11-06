@EndUserText.label : 'FMON: tables approved for the dynamic reader'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zcd_fmon_tabwl {
  key mandt      : abap.clnt not null;
  // Table a source or lot configuration may name (audit A51); anything else is refused
  key table_name : abap.char(30) not null;
  // Approved field, or * for every field of the table
  key field_name : abap.char(30) not null;
  active         : abap_boolean;
  description    : abap.char(60);
  // RAP configuration apps (design 5): set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}

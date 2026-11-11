@EndUserText.label : 'Ops framework: link registry object fields'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zca_ops_lnkfld {
  key mandt      : abap.clnt not null;
  key object_id  : abap.char(30) not null;
  // DDIC field of the table / element of the CDS view (checked on save against the runtime DDIC)
  key field_name : abap.char(30) not null;
  // Layer that declares the field: a customer layer adds its custom fields to a standard object here
  layer_id       : abap.char(10);
  // Source of the object (repeated so that the field is checked on save without reading the object row)
  source_name    : abap.char(30);
  data_element   : abap.char(30);
  // Blank none, M masked (last four characters shown), H hidden (never shown, never a key)
  sensitivity    : abap.char(1);
  // C confirmed, V VERIFY (VERIFY_REF names the item); an active link uses confirmed fields only
  evidence       : abap.char(1);
  verify_ref     : abap.char(20);
  description    : abap.char(60);
  // RAP configuration app: set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}

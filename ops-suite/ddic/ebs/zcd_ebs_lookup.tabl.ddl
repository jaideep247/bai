@EndUserText.label : 'EBS: generic lookups of rule R21'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zcd_ebs_lookup {
  key mandt      : abap.clnt not null;
  // Referenced by PARAM1 of a ZCD_BTC_RULE row with rule R21
  key lookup_id  : abap.char(10) not null;
  // Table read (validated against the DDIC at run time)
  table_name     : abap.char(30);
  key_field      : abap.char(30);
  // DOCNO (payment document, padded) / ZTNUM (check number) / REFERENCE (as delivered)
  key_kind       : abap.char(10);
  // REFERENCE only: 0 = as delivered, > 0 = right-aligned with leading zeros
  key_length     : abap.int4;
  // Blank = existence check only
  status_field   : abap.char(30);
  // Comma-separated; blank = any status
  allowed_values : abap.char(255);
  // Finding check codes (blank = LOOKUP_NOT_FOUND / LOOKUP_STATUS)
  not_found_code : abap.char(30);
  status_code    : abap.char(30);
  active         : abap_boolean;
  // RAP configuration apps (design 5): set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}

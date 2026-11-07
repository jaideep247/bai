@EndUserText.label : 'Health check: factory calendar per house bank and class'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zcd_hck_pmbank {
  key mandt        : abap.clnt not null;
  key flow         : abap.char(1) not null;
  // ZCD_HCK_PMCLASS-METHOD_CLASS
  key method_class : abap.char(3) not null;
  // house bank of the payment (DPAYH-HBKID)
  key hbkid        : abap.char(5) not null;
  // factory calendar of this bank (e.g. UK / German bank holidays); overrides the class calendar
  calendar         : abap.char(2);
  description      : abap.char(60);
  active           : abap_boolean;
  changed_by       : syuname;
  changed_at       : timestampl;
  // RAP configuration apps (design 5): set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}

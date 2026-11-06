@EndUserText.label : 'Health check: table whitelist for aggregates'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zcd_hck_tabwl {
  key client    : abap.clnt not null;
  key tabname   : abap.char(30) not null;
  description   : abap.char(60);
  active        : abap_boolean;
  // reviewer of the entry (security sign-off: who allowed reading this table)
  approved_by   : syuname;
  changed_by    : syuname;
  changed_at    : timestampl;
}

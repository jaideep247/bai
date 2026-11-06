@EndUserText.label : 'Health check: tables under config drift control'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zcd_hck_drift {
  key client    : abap.clnt not null;
  key tabname   : abap.char(30) not null;
  description   : abap.char(60);
  active        : abap_boolean;
  changed_by    : syuname;
  changed_at    : timestampl;
}
// Only customizing tables (small). The hash reads the whole table ordered by primary key.

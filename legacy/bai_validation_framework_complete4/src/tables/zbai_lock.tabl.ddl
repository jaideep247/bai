@EndUserText.label : 'BAI Validation Lock Table'
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #ALLOWED
define table zbai_lock {
  key client      : mandt not null;
  key lock_key    : char50 not null;
  description     : char100;
  created_by      : syuname;
  created_at      : timestampl;
}

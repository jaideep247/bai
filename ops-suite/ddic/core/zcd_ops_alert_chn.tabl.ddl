@EndUserText.label : 'Ops suite: alert channels (SM30)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zcd_ops_alert_chn {
  key mandt     : abap.clnt not null;
  key channel   : abap.char(10) not null;
  // Implements ZIF_CD_OPS_ALERT_CHANNEL
  class_name    : seoclsname;
  // Default destination when the rule has none
  destination   : abap.char(255);
  active        : abap_boolean;
  changed_by    : syuname;
  changed_at    : timestampl;
}

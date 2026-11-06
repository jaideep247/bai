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
  // RAP configuration apps (design 5): set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}

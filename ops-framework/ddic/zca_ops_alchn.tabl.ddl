@EndUserText.label : 'Ops framework: alert channels (SM30)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zca_ops_alchn {
  key mandt     : abap.clnt not null;
  key channel   : abap.char(10) not null;
  // Implements ZIF_CA_OPS_ALERT_CHANNEL
  class_name    : seoclsname;
  // Default destination when the rule has none
  destination   : abap.char(255);
  active        : abap_boolean;
  // Default e-mail template of the channel when the rule names none (SMTG template ID)
  template_id   : abap.char(30);
  changed_by    : syuname;
  changed_at    : timestampl;
  // RAP configuration apps (design 5): set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}

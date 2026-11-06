@EndUserText.label : 'Ops suite: alert delivery log (audit)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #DISPLAY
define table zcd_ops_alert_log {
  key mandt     : abap.clnt not null;
  key alert_id  : sysuuid_x16 not null;
  rule_id       : abap.char(10);
  channel       : abap.char(10);
  run_id        : sysuuid_x16;
  module        : abap.char(4);
  sent_at       : timestampl;
  // S sent, F failed, T throttled, Q quiet hours
  status        : abap.char(1);
  destination   : abap.char(255);
  subject       : abap.char(255);
  error         : abap.char(255);
  created_by    : syuname;
}
// Secondary index ZCD_OPS_ALERT_LOG~RUL : MANDT, RULE_ID, SENT_AT (throttling / escalation)

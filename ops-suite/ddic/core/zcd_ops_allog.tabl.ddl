@EndUserText.label : 'Ops suite: alert delivery log (audit)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #DISPLAY
define table zcd_ops_allog {
  key mandt     : abap.clnt not null;
  key alert_id  : sysuuid_x16 not null;
  rule_id       : abap.char(10);
  channel       : abap.char(10);
  run_id        : sysuuid_x16;
  pe_area       : abap.char(4);
  sent_at       : timestampl;
  // S submitted (accepted by the channel), F failed, T throttled, Q quiet hours, C claimed, R repeat, P partial
  status        : abap.char(1);
  destination   : abap.char(255);
  subject       : abap.char(255);
  error         : abap.char(255);
  created_by    : syuname;
  // Alert intent (SHA-1 of rule, run, channel, destination, subject) and attempt (A17)
  intent_key    : abap.char(40);
  attempt       : abap.int4;
}
// Secondary index RUL: throttling / escalation
// @index RUL: MANDT, RULE_ID, SENT_AT
// Secondary index INT (UNIQUE): one dispatcher per alert intent and attempt (audit A17)
// @index INT UNIQUE: MANDT, INTENT_KEY, ATTEMPT
// Status: S submitted (channel accepted; e-mail delivery is in SOST), F failed, T throttled, Q quiet hours, C claimed (in delivery), R repeat
//   (carried-forward exception, not re-alerted), P partially delivered

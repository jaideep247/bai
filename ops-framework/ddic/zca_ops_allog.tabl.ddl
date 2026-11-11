@EndUserText.label : 'Ops framework: alert delivery log (audit)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #DISPLAY
define table zca_ops_allog {
  key mandt     : abap.clnt not null;
  key alert_id  : sysuuid_x16 not null;
  rule_id       : abap.char(10);
  channel       : abap.char(10);
  run_id        : sysuuid_x16;
  area       : zca_param_area_id;
  sent_at       : timestampl;
  // S submitted (accepted by the channel), F failed, T throttled, Q quiet hours, C claimed, R repeat, P partial,
  // D planned downtime (suppressed), K correlated children (suppressed, alerted with their parent) (2026-11-11)
  status        : abap.char(1);
  destination   : abap.char(255);
  subject       : abap.char(255);
  error         : abap.char(255);
  created_by    : syuname;
  // Alert intent (SHA-1 of rule, run, channel, destination, subject) and attempt (A17)
  intent_key    : abap.char(40);
  attempt       : abap.int4;
  // E-mail template asked for, renderer used (SMTG / BUILTIN) and the fallback or table note (2026-11-10)
  template_id   : abap.char(30);
  renderer      : abap.char(10);
  render_info   : abap.char(255);
  // Escalation until acknowledged (2026-11-11): the n-th escalation of one exception (0 = an ordinary alert);
  // RUN_ID / FINDING_NO = the exception row escalated (one row per attempt, intent per exception and step)
  esc_step      : abap.int4;
  finding_no    : abap.int4;
}
// Secondary index RUL: throttling / escalation
// @index RUL: MANDT, RULE_ID, SENT_AT
// Secondary index INT (UNIQUE): one dispatcher per alert intent and attempt (audit A17)
// @index INT UNIQUE: MANDT, INTENT_KEY, ATTEMPT
// Status: S submitted (channel accepted; e-mail delivery is in SOST), F failed, T throttled, Q quiet hours, C claimed (in delivery), R repeat
//   (carried-forward exception, not re-alerted), P partially delivered, D planned downtime (findings in an
//   approved window, not alerted), K correlated children (alerted with their parent only) - 2026-11-11

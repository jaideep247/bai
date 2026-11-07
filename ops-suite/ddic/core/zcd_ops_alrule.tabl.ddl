@EndUserText.label : 'Ops suite: alert rules (SM30)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zcd_ops_alrule {
  key mandt       : abap.clnt not null;
  key rule_id     : abap.char(10) not null;
  // HCK / FMON / EBS or * for every payment engine area
  pe_area          : abap.char(4);
  // B, E, W or I - lowest severity that triggers
  min_severity    : abap.char(1);
  // PCRE on the complete value of the finding, case ignored; blank = any
  rule_pattern    : abap.char(35);
  check_pattern   : abap.char(35);
  group1_pattern  : abap.char(35);
  group2_pattern  : abap.char(35);
  // Run-level trigger: R or A (run RAG equal or worse); blank = none
  min_rag         : abap.char(1);
  on_abort        : abap_boolean;
  // EMAIL / APPLOG (ZCD_OPS_ALCHN)
  channel         : abap.char(10);
  // e-mail list | OBJECT/SUBOBJECT | SM59 destination
  destination     : abap.char(255);
  digest          : abap_boolean;
  max_items       : abap.int4;
  throttle_min    : abap.int4;
  quiet_from      : abap.tims;
  quiet_to        : abap.tims;
  escalate_after  : abap.int4;
  escalation_dest : abap.char(255);
  // X = a due escalation is delivered even inside the throttle window (audit A46)
  esc_override    : abap_boolean;
  active          : abap_boolean;
  changed_by      : syuname;
  changed_at      : timestampl;
  // RAP configuration apps (design 5): set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}

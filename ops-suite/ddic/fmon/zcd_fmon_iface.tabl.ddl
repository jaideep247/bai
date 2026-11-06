@EndUserText.label : 'FMON: file interface definition (SM30)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zcd_fmon_iface {
  key mandt    : abap.clnt not null;
  key iface_id : abap.char(20) not null;
  // O = outbound (SAP -> PRISM -> bank), I = inbound (bank -> SAP)
  direction    : abap.char(1);
  // PAYMENT, ACK, STATEMENT, RETURNS, NOC, POSPAY, OTHER
  file_type    : abap.char(10);
  // Blank or '*' = default row for any source / LOB (acceptance test 2)
  source_sys   : abap.char(10);
  target_sys   : abap.char(10);
  pay_method   : abap.char(10);
  lob          : abap.char(10);
  bank_key     : abap.char(15);
  // CP pattern on the file name, e.g. ACH_PNC_*  (most specific match wins)
  name_pattern : abap.char(128);
  min_bytes    : abap.int8;
  // 0 = no upper bound
  max_bytes    : abap.int8;
  ack_expected : abap_boolean;
  // FILE (collections) or PAYMENT (disbursements, one ack row per payment)
  ack_level    : abap.char(8);
  owner        : syuname;
  active       : abap_boolean;
  description  : abap.char(60);
  // RAP configuration apps (design 5): set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}
// Alert routing is not maintained here: ZCD_OPS_ALERT_RULE (payment engine area FMON, group1 = IFACE_ID pattern).

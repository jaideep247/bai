@EndUserText.label : 'Ops suite: run header (HCK/FMON/EBS)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #DISPLAY
define table zcd_ops_run {
  key mandt     : abap.clnt not null;
  key run_id    : sysuuid_x16 not null;
  module        : abap.char(4);
  variant       : abap.char(30);
  test_mode     : abap_boolean;
  started_at    : timestampl;
  ended_at      : timestampl;
  status        : abap.char(1);
  rag           : abap.char(1);
  total_items   : abap.int4;
  passed_items  : abap.int4;
  failed_items  : abap.int4;
  blocked_items : abap.int4;
  warning_items : abap.int4;
  finding_count : abap.int4;
  runtime_ms    : abap.int4;
  message       : abap.char(255);
  created_by    : syuname;
}
// Secondary index ZCD_OPS_RUN~MOD: MANDT, MODULE, STARTED_AT (morning report / last-run lookups)

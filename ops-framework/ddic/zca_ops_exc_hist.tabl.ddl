@EndUserText.label : 'Ops framework: exception action history'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #DISPLAY
define table zca_ops_exc_hist {
  key mandt       : abap.clnt not null;
  key hist_uuid   : sysuuid_x16 not null;
  // Exception (ZCA_OPS_FINDING key)
  run_id          : sysuuid_x16;
  finding_no      : abap.int4;
  // ASSIGN, RESOLVE, WAIVE_REQ, WAIVE_OK, MANUAL
  action          : abap.char(10);
  from_disp       : abap.char(1);
  to_disp         : abap.char(1);
  owner           : syuname;
  reason          : abap.char(255);
  // Evidence or document reference (e.g. the reference of a manual handling)
  reference       : abap.char(70);
  created_by      : syuname;
  created_at      : timestampl;
}
// Secondary index FND: history of one exception
// @index FND: MANDT, RUN_ID, FINDING_NO

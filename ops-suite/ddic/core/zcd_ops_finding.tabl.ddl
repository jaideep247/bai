@EndUserText.label : 'Ops suite: findings / owned exceptions'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #DISPLAY
define table zcd_ops_finding {
  key client    : abap.clnt not null;
  key run_id    : sysuuid_x16 not null;
  key finding_no : abap.int4 not null;
  module        : abap.char(4);
  object_type   : abap.char(10);
  object_key    : abap.char(70);
  group1        : abap.char(35);
  group2        : abap.char(35);
  rule_id       : abap.char(10);
  check_code    : abap.char(30);
  severity      : abap.char(1);
  action        : abap.char(10);
  amount        : abap.dec(23,2);
  currency      : abap.char(5);
  reference     : abap.char(35);
  message       : abap.char(255);
  details       : abap.string(0);
  // Exception lifecycle: O = open, I = information, A = assigned, R = resolved, W = waived
  disposition   : abap.char(1);
  owner         : syuname;
  due_date      : abap.dats;
  resolved_by   : syuname;
  resolved_at   : timestampl;
  resolution    : abap.char(255);
  created_by    : syuname;
  created_at    : timestampl;
}
// Secondary indexes:
//   ZCD_OPS_FINDING~OPN : CLIENT, MODULE, DISPOSITION, DUE_DATE   (exception queue / aging)
//   ZCD_OPS_FINDING~OBJ : CLIENT, MODULE, OBJECT_TYPE, OBJECT_KEY (drill-down, idempotent re-validation)

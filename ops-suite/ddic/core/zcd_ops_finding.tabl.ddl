@EndUserText.label : 'Ops suite: findings / owned exceptions'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #DISPLAY
define table zcd_ops_finding {
  key mandt     : abap.clnt not null;
  key run_id    : sysuuid_x16 not null;
  key finding_no : abap.int4 not null;
  pe_area        : abap.char(4);
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
  // Exception lifecycle: O = open, I = information, A = assigned, R = resolved, W = waived, S = superseded
  disposition   : abap.char(1);
  owner         : syuname;
  due_date      : abap.dats;
  resolved_by   : syuname;
  resolved_at   : timestampl;
  resolution    : abap.char(255);
  // Carry-forward: first run that raised this exception, how often it was raised,
  // and the later run whose row replaced this one (disposition S)
  first_seen_at : timestampl;
  occurrences   : abap.int4;
  superseded_by : sysuuid_x16;
  // Waiver valid until (disposition W); a re-run keeps the waiver while valid
  waiver_until  : abap.dats;
  // Waiver request (exceptions app, four-eyes): requester, time and reason;
  // approved by a different user (RESOLVED_BY), then disposition W
  waiver_req_by : syuname;
  waiver_req_at : timestampl;
  waiver_reason : abap.char(255);
  created_by    : syuname;
  created_at    : timestampl;
}
// Secondary indexes:
//   ZCD_OPS_FINDING~OPN : MANDT, PE_AREA, DISPOSITION, DUE_DATE   (exception queue / aging)
//   ZCD_OPS_FINDING~OBJ : MANDT, PE_AREA, OBJECT_TYPE, OBJECT_KEY (drill-down, idempotent re-validation)

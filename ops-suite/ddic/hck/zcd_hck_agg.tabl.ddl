@EndUserText.label : 'Health check: generic aggregate definitions'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zcd_hck_agg {
  key client    : abap.clnt not null;
  key check_id  : abap.char(20) not null;
  // becomes the metric name; one check may hold several aggregates
  key agg_id    : abap.char(10) not null;
  description   : abap.char(60);
  // must be in ZCD_HCK_TABWL; all field names are checked against the runtime DDIC
  tabname       : abap.char(30);
  // COUNT or SUM
  agg_func      : abap.char(5);
  sum_field     : abap.char(30);
  // DATS field; AGE = older than AGE_DAYS_MIN days, DAY = exactly report date - AGE_DAYS_MIN
  date_field    : abap.char(30);
  date_mode     : abap.char(3);
  age_days_min  : abap.int4;
  // result per value of this field becomes DIM1 (e.g. BUKRS, source, LOB)
  group_field   : abap.char(30);
  // operators EQ NE GT LT GE LE IN (IN: comma list); values are quoted, never concatenated raw
  cond1_field   : abap.char(30);
  cond1_op      : abap.char(2);
  cond1_value   : abap.char(70);
  cond2_field   : abap.char(30);
  cond2_op      : abap.char(2);
  cond2_value   : abap.char(70);
  cond3_field   : abap.char(30);
  cond3_op      : abap.char(2);
  cond3_value   : abap.char(70);
  changed_by    : syuname;
  changed_at    : timestampl;
}

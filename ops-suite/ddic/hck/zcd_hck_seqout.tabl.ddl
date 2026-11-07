@EndUserText.label : 'Health check: outcomes of BAI role sequences'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zcd_hck_seqout {
  key mandt        : abap.clnt not null;
  key flow         : abap.char(1) not null;
  key method_class : abap.char(3) not null;
  // order of evaluation: the first active pattern matching the whole sequence decides
  key seq          : abap.numc(3) not null;
  // PCRE matched to the complete ordered role sequence, e.g. ORIGINAL,RETURNED
  seq_pattern      : abap.char(200);
  // open list of configuration (e.g. CLEARED, RETURNED, REDEPOSIT_PENDING), named in rules
  outcome          : abap.char(20);
  // returns lot items expected (0-9), blank = not checked
  expected_dfkkrp  : abap.char(1);
  // pending outcome: calendar days after the last line it may stay (0 = no limit)
  max_age_days     : abap.int4;
  // severity when the evidence does not match (blank = E)
  severity         : abap.char(1);
  description      : abap.char(60);
  active           : abap_boolean;
  changed_by       : syuname;
  changed_at       : timestampl;
  // RAP configuration apps (design 5): set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}

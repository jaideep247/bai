@EndUserText.label : 'Health check: BAI code roles per flow and method class'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zcd_hck_btcrole {
  key mandt        : abap.clnt not null;
  key flow         : abap.char(1) not null;
  key method_class : abap.char(3) not null;
  // BAI2 / ISO / PRTRY (as ZCD_BTC_MAP); from the statement format (FEBEP-VORGC or VGEXT)
  key scheme       : abap.char(5) not null;
  // code in the scheme; the same code means different things per flow / class
  key btc_code     : abap.char(35) not null;
  // open list of configuration (e.g. ORIGINAL, RETURNED, COLLECTED, COLLECT_FAIL)
  role             : abap.char(15);
  // X: the amount of a line of this role is compared with the returns lot (DFKKRP), R: with the
  // payment amount of the cheque (DPAYH via DFKKCR-DOC1R = AUGBL), blank: not compared
  compare_amount   : abap.char(1);
  description      : abap.char(60);
  active           : abap_boolean;
  changed_by       : syuname;
  changed_at       : timestampl;
  // RAP configuration apps (design 5): set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}

@EndUserText.label : 'EBS: bank transaction code map (SM30)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zcd_btc_map {
  key mandt    : abap.clnt not null;
  // BAI2 / ISO (CAMT Domain-Family-SubFamily) / PRTRY (proprietary)
  key scheme   : abap.char(5) not null;
  // BAI2: '168' - ISO: 'PMNT-ICDT-ARET' or family row 'PMNT-ICDT'
  key btc_code : abap.char(35) not null;
  // Bank-specific row; blank = default row for every bank
  key bank_key : abap.char(15) not null;
  // D disbursement, C collection, * any
  key flow_type : abap.char(1) not null;
  // Master prompt category C01..X01
  category     : abap.char(4);
  // Rule group in ZCD_BTC_RULE; blank = category
  rule_group   : abap.char(10);
  // Expected direction C/D/*
  exp_cdi      : abap.char(1);
  pay_method   : abap.char(10);
  posting_rule : abap.char(4);
  ret_reason   : abap.char(4);
  // AUTO_POST / EXCEPTION / BLOCK / NOTIFY / ON_ACCOUNT
  action       : abap.char(10);
  active       : abap_boolean;
  description  : abap.char(60);
  // A26: expected disposition - blank = posted as usual, NOT_POSTED = never posted (sweeps)
  disposition  : abap.char(10);
  changed_by   : syuname;
  changed_at   : timestampl;
  // RAP configuration apps (design 5): set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}

@EndUserText.label : 'Ops suite: typed mapping - bank transaction codes (ZBTM)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zcd_ops_mapbtm {
  key mandt       : abap.clnt not null;
  // Mapping version: the reader reads the version of parameter POSTAREA_VERSION_BTM
  key version     : abap.numc(4) not null;
  // BAI2 / ISO / PRTRY
  key scheme      : abap.char(5) not null;
  // BAI2 type code; ISO domain (e.g. PMNT); PRTRY code
  key code        : abap.char(35) not null;
  // ISO family (e.g. ICDT); blank for BAI2 / PRTRY
  key family      : abap.char(35) not null;
  // ISO sub-family (e.g. ARET); * = the family row; blank for BAI2 / PRTRY
  key sub_family  : abap.char(35) not null;
  // Bank identifier of the statement (ZCD_EBS_ACCT-BANK_KEY); * = every bank
  key bank        : abap.char(15) not null;
  // D / C; * = any flow
  key flow        : abap.char(1) not null;
  // Requirements baseline category (C01 ... X01)
  category        : abap.char(4);
  // Rule group in ZCD_BTC_RULE (blank = category)
  rule_group      : abap.char(10);
  // Expected direction C / D / * / blank
  exp_cdi         : abap.char(1);
  // Payment method family (ACH, WIRE, CHECK ...)
  pay_method      : abap.char(10);
  // Expected posting rule
  posting_rule    : abap.char(4);
  // AUTO_POST / EXCEPTION / BLOCK / NOTIFY / ON_ACCOUNT / blank
  action          : abap.char(10);
  // POSTED = posted as usual, NOT_POSTED = never posted (sweeps, audit A26); required - never blank
  disposition     : abap.char(10);
  // RAP configuration apps (design 5): set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}
// Read by ZCL_CD_OPS_PAMAP_DAO when parameter POSTAREA_SOURCE_BTM = T (user decision 2026-11-15: ZBTM, including its
// disposition, uses this table - 7 results and keys of 35 / 15 characters do not fit TFK033D, CHAR 12 and 6 results).
// Layout and precedence: docs/FICA_Posting_Areas.md. New rows only by transport (DV1).

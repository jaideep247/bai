@EndUserText.label : 'Ops framework: break analysis snapshot'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #DISPLAY
define table zca_ops_brkrun {
  key mandt     : abap.clnt not null;
  // One analysis of one clearing account at one key date (report ZCA_OPS_BRK_RUN); written only by ZCL_CA_OPS_BRK_DAO
  key snap_id   : sysuuid_x16 not null;
  area          : zca_param_area_id;
  acct_id       : abap.char(20);
  bukrs         : bukrs;
  hkont         : saknr;
  ledger        : abap.char(2);
  // Journal lines posted up to the key date are open at it; later lines (up to TO_DATE) may clear a group
  key_date      : abap.dats;
  from_date     : abap.dats;
  to_date       : abap.dats;
  // S complete, P partial (a cap was reached: groups or lines not all read)
  status        : abap.char(1);
  // Configuration version of the analysis: SHA-1 of the account row, the effective buckets, rules and conditions
  // and the BRK_ parameter values (ZCL_CA_OPS_CFG_VERSION) - carried to the findings of ZCL_CA_OPS_CHK_BREAK
  cfg_version   : abap.char(40);
  group_count   : abap.int4;
  item_count    : abap.int4;
  other_count   : abap.int4;
  started_at    : timestampl;
  ended_at      : timestampl;
  created_by    : syuname;
  message       : abap.char(255);
}
// ACC (2026-11-11): the latest snapshot of an account (check ZCL_CA_OPS_CHK_BREAK, CDS ZI_CA_OpsBrkLatest)
// @index ACC: MANDT, AREA, ACCT_ID, KEY_DATE
// Retention: ZCA_OPS_RETENTION target BREAK (RETENTION_DAYS_BREAK, area CA_OPS) - header, groups and items

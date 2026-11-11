@EndUserText.label : 'Ops framework: break analysis accounts'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zca_ops_brkacc {
  key mandt     : abap.clnt not null;
  key area      : zca_param_area_id not null;
  // Clearing account of the break analysis (docs/BREAK_ANALYSIS.md): one G/L clearing account of one company code
  key acct_id   : abap.char(20) not null;
  bukrs         : bukrs;
  hkont         : saknr;
  // Ledger of the journal lines (blank = parameter BRK_LEDGER)
  ledger        : abap.char(2);
  // Business process of the area (ZCA_OPS_PROC) the account belongs to - its catalogue activation decides whether
  // the account is analysed (process catalogue: G/L transfer and clearing)
  process_id    : abap.char(20);
  // Days of journal lines before the key date (0 = BRK_LOOKBACK_DAYS) and after it (later lines that clear a
  // group, 0 = BRK_FORWARD_DAYS)
  lookback_days : abap.int4;
  forward_days  : abap.int4;
  // Groups (assignment and currency) read at most (0 = BRK_MAX_GROUPS); a cut result makes the snapshot partial
  max_groups    : abap.int4;
  description   : abap.char(60);
  active        : abap_boolean;
  // RAP configuration app: set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}
// Read by ZCL_CA_OPS_BRK_DAO=>GET_ACCOUNTS (area, active). The journal read of an account needs ACDOCA by ledger,
// company code and account (primary key prefix RLDNR / RBUKRS, RACCT in the column store) - PlanViz BRK-PV1.

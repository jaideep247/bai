@EndUserText.label : 'Ops framework: account flow accounts'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zca_ops_flwacc {
  key mandt     : abap.clnt not null;
  key area      : zca_param_area_id not null;
  key flow_id   : abap.char(10) not null;
  // Column of the dashboard: one G/L account (or range) of one company code in one role
  key flow_acct : abap.char(20) not null;
  // RECEIVABLE, PAYABLE, OUTSIDE (no control point: expense, revenue), SETTLEMENT, CLEARING, CASH, CLARIFICATION
  role          : abap.char(15);
  bukrs         : bukrs;
  // Transaction currency (blank = every currency; each currency is its own slice, never summed across)
  currency      : abap.char(5);
  // G/L account, or the first of a range (HKONT_TO blank = this account only)
  hkont_from    : saknr;
  hkont_to      : saknr;
  // G = stages from the journal lines; F = stages from the FI-CA documents (subledger-posted account: the journal
  // holds only the G/L transfer per reconciliation key) - its journal lines are shown as reached G/L
  line_source   : abap.char(1);
  // Display order of the columns
  seq           : abap.int4;
  // What existing checks account for in the closing position: plug-in class (ZIF_CA_OPS_FLOW_SOURCE; blank = not
  // evaluated - shown grey, never as zero) and the tile it feeds (TRANSIT, CLARIFY, OPEN, BANK)
  eval_class    : abap.char(30);
  eval_category : abap.char(10);
  description   : abap.char(60);
  active        : abap_boolean;
  // RAP configuration app: set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}
// Read by ZI_CA_OpsFlowAcct; the journal reads of the dashboard reach I_JournalEntryItem by ledger, company code,
// account and posting date (ACDOCA RLDNR / RBUKRS / RACCT / BUDAT) - PlanViz FLOW-PV1 / FLOW-PV2.

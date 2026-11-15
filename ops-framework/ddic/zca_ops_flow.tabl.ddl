@EndUserText.label : 'Ops framework: account flows'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zca_ops_flow {
  key mandt     : abap.clnt not null;
  key area      : zca_param_area_id not null;
  // Account flow of the reconciliation dashboard (docs/ACCOUNT_FLOW.md): one money flow through its posting stages,
  // e.g. DISB (disbursements) or COLL (collections) - rows the stages, columns the accounts by role
  key flow_id   : abap.char(10) not null;
  description   : abap.char(60);
  // D = disbursement (money leaves), C = collection (money arrives) - documentation and the sign of the tiles
  direction     : abap.char(1);
  // Ledger of the journal lines (blank = parameter FLOW_LEDGER)
  jrnl_ledger   : abap.char(2);
  // Business process of the area (ZCA_OPS_PROC): a flow whose process is not in effect is not evaluated
  process_id    : abap.char(20);
  active        : abap_boolean;
  // RAP configuration app: set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}
// Read by ZI_CA_OpsFlowAcct (CDS of the dashboard) and ZCL_CA_OPS_FLOW_DAO=>GET_FLOWS (evaluation).

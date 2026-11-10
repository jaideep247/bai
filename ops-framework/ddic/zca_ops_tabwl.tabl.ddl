@EndUserText.label : 'Ops framework: tables approved for aggregate checks'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zca_ops_tabwl {
  key mandt      : abap.clnt not null;
  // Area whose aggregate checks may read the table
  key area       : zca_param_area_id not null;
  key table_name : abap.char(30) not null;
  // Production switches a row off here (never deletes); new rows by transport
  active         : abap_boolean;
  // Reviewer of the entry (security sign-off: who allowed reading this table)
  approved_by    : syuname;
  description    : abap.char(60);
  // RAP configuration app: set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}
// Read by key (area, table): ZCL_CA_OPS_CHECK_DAO=>IS_TABLE_APPROVED. Besides this list the running user needs
// S_TABU_NAM display of the table (ZIF_CA_OPS_AUTH=>MAY_READ_TABLE).

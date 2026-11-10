@EndUserText.label : 'Ops suite: tables approved per area and purpose'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zcd_ops_tabwl {
  key mandt      : abap.clnt not null;
  // Payment engine area of the reader: CD_FMON, CD_HCK or CD_EBS (table consolidation 2026-11-08; EBS 2026-11-10;
  // parameter areas of ZCA_PARAM, data element ZCA_PARAM_AREA_ID of the framework, 2026-11-10)
  key pe_area    : zca_param_area_id not null;
  // What the reader does with the table: FMON SOURCE (dynamic reader of ZCD_FMON_SRC / _LOTCFG,
  // audit A51), HCK READ (aggregates, value queries, queue and evidence sources), HCK DRIFT
  // (configuration drift hash), EBS LOOKUP (rule R21: key and status field of ZCD_EBS_LOOKUP, one
  // row per field, 2026-11-10); every reader filters by its area and purpose
  key purpose    : abap.char(10) not null;
  key table_name : abap.char(30) not null;
  // Approved field; blank = the whole table (FMON may narrow a table to fields, HCK rows are blank)
  key field_name : abap.char(30) not null;
  // Production edits an existing row (switched off here, never deleted); new rows by transport
  active         : abap_boolean;
  // Reviewer of the entry (security sign-off: who allowed reading this table)
  approved_by    : syuname;
  description    : abap.char(60);
  // RAP configuration apps (design 5): set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}
// Replaces ZCD_FMON_TABWL, ZCD_HCK_TABWL and ZCD_HCK_DRIFT (table consolidation 2026-11-08).
// Read by key (area, purpose, table): ZCL_CD_FMON_DAO=>CHECK_READ_ALLOWED,
// ZCL_CD_HCK_DAO=>IS_TABLE_WHITELISTED / GET_DRIFT_TABLES. Maintained in the core configuration app.

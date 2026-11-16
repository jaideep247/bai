@EndUserText.label : 'Ops framework: payment file adapters'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zca_ops_pfadp {
  key mandt     : abap.clnt not null;
  key area      : zca_param_area_id not null;
  key file_type : abap.char(10) not null;
  // Role of the adapter: FILE (files of a payment run), TRANSFER (middleware or direct transfer), ACK (bank
  // acknowledgement), SCHED (scheduler / SAP job), STMT (bank statement evidence), TICKET (ticket sink),
  // CALENDAR (business calendar)
  key role      : abap.char(10) not null;
  // Source ID of the adapter's events (status mapping ZCA_OPS_PFMAP, source state ZCA_OPS_PFSRC, evidence)
  source_id     : abap.char(10);
  // Plug-in class (ZIF_CA_OPS_PF_ADAPTER and the interface of the role; product or customer class)
  class_name    : abap.char(30);
  // Adapter settings in the adapter's own syntax (e.g. job programs, grouping fields); documented per class
  setting       : abap.char(255);
  // Source type of the evidence: SAP, MW (middleware / transfer), BANK
  source_type   : abap.char(4);
  active        : abap_boolean;
  // RAP configuration app: set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}
// The two integration setups of docs/PAYMENT_FILE_LIFECYCLE.md section 9 differ only in these rows and the classes
// they name; no product object changes.

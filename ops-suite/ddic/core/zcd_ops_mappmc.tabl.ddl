@EndUserText.label : 'Ops suite: typed mapping - payment method classes (ZPMC)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zcd_ops_mappmc {
  key mandt       : abap.clnt not null;
  // Mapping version: the reader reads the version of parameter POSTAREA_VERSION_PMC
  key version     : abap.numc(4) not null;
  // D disbursement / C collection
  key flow        : abap.char(1) not null;
  // SAP payment method (one row per payment method)
  key pay_method  : abap.char(1) not null;
  // * = the class of the payment method at every house bank; a house bank = only its factory calendar
  key house_bank  : abap.char(5) not null;
  // Method class (WIR, ACH, CHQ, CRD, ACI ...); flow + class = the scope of ZBTR LIFECYCLE
  method_class    : abap.char(3);
  // * rows: VALUE_DATE / ISSUE_DATE; house-bank rows: blank
  age_basis       : abap.char(10);
  // Factory calendar (* row blank = PARAM1 of A_INFLIGHT; house-bank row: required)
  calendar        : abap.char(2);
  // RAP configuration apps (design 5): set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}
// Read by ZCL_CD_OPS_PAMAP_DAO and ZI_CD_PayMethodCls when parameter POSTAREA_SOURCE_PMC = T (delivered P: the layout
// fits the posting area ZPMC). Layout and precedence: docs/FICA_Posting_Areas.md. New rows only by transport (DV1).

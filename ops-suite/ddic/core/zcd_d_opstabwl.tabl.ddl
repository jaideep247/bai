@EndUserText.label : 'Draft: Approved tables per reader'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zcd_d_opstabwl {
  key mandt : abap.clnt not null;
  key paymentenginearea : abap.char(4) not null;
  key purpose : abap.char(10) not null;
  key tablename : abap.char(30) not null;
  key fieldname : abap.char(30) not null;
  singletonid : abap.int1;
  active : abap_boolean;
  approvedby : syuname;
  description : abap.char(60);
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}

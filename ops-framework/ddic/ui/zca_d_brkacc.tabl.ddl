@EndUserText.label : 'Draft: Break analysis clearing accounts'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zca_d_brkacc {
  key mandt : abap.clnt not null;
  key area : zca_param_area_id not null;
  key acctid : abap.char(20) not null;
  singletonid : abap.int1;
  bukrs : bukrs;
  hkont : saknr;
  ledger : abap.char(2);
  processid : abap.char(20);
  lookbackdays : abap.int4;
  forwarddays : abap.int4;
  maxgroups : abap.int4;
  description : abap.char(60);
  active : abap_boolean;
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}

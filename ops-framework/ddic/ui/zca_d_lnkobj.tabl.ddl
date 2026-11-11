@EndUserText.label : 'Draft: Link registry business objects'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zca_d_lnkobj {
  key mandt : abap.clnt not null;
  key objectid : abap.char(30) not null;
  singletonid : abap.int1;
  layerid : abap.char(10);
  sourcename : abap.char(30);
  sourcekind : abap.char(1);
  keyfields : abap.char(255);
  description : abap.char(60);
  active : abap_boolean;
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}

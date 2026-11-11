@EndUserText.label : 'Draft: Process catalogue tables'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zca_d_cattab {
  key mandt : abap.clnt not null;
  key processid : abap.char(20) not null;
  key tabname : abap.char(30) not null;
  singletonid : abap.int1;
  tabrole : abap.char(1);
  linkobject : abap.char(30);
  description : abap.char(60);
  evidence : abap.char(1);
  verifyref : abap.char(20);
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}

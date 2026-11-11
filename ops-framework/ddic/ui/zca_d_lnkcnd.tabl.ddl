@EndUserText.label : 'Draft: Link registry link conditions'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zca_d_lnkcnd {
  key mandt : abap.clnt not null;
  key linkid : abap.char(30) not null;
  key condno : abap.numc(3) not null;
  singletonid : abap.int1;
  condkind : abap.char(8);
  fromref : abap.char(61);
  toref : abap.char(61);
  condvalue : abap.char(70);
  transform : abap.char(6);
  transformarg : abap.char(20);
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}

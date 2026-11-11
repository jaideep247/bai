@EndUserText.label : 'Draft: Process catalogue dependencies'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zca_d_catdep {
  key mandt : abap.clnt not null;
  key processid : abap.char(20) not null;
  key predid : abap.char(20) not null;
  singletonid : abap.int1;
  depkind : abap.char(1);
  description : abap.char(60);
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}

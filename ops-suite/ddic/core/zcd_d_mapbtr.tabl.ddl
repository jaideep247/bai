@EndUserText.label : 'Draft: Bank code roles (typed ZBTR)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zcd_d_mapbtr {
  key mandt : abap.clnt not null;
  key version : abap.numc(4) not null;
  key usage : abap.char(10) not null;
  key scope : abap.char(10) not null;
  key scheme : abap.char(5) not null;
  key code : abap.char(35) not null;
  key family : abap.char(35) not null;
  key subfamily : abap.char(35) not null;
  singletonid : abap.int1;
  role : abap.char(15);
  compareamount : abap.char(1);
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}

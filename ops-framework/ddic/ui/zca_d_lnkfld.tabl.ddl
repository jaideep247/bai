@EndUserText.label : 'Draft: Link registry object fields'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zca_d_lnkfld {
  key mandt : abap.clnt not null;
  key objectid : abap.char(30) not null;
  key fieldname : abap.char(30) not null;
  singletonid : abap.int1;
  layerid : abap.char(10);
  sourcename : abap.char(30);
  dataelement : abap.char(30);
  sensitivity : abap.char(1);
  evidence : abap.char(1);
  verifyref : abap.char(20);
  description : abap.char(60);
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}

@EndUserText.label : 'Draft: Expected files per day type'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zcd_d_fmcal {
  key mandt : abap.clnt not null;
  key ifaceid : abap.char(20) not null;
  key daytype : abap.char(12) not null;
  singletonid : abap.int1;
  expectedcount : abap.int4;
  windowfrom : abap.tims;
  windowto : abap.tims;
  fcalid : abap.char(2);
  active : abap_boolean;
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}

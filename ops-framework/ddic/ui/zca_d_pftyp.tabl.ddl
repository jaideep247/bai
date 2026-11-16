@EndUserText.label : 'Draft: Payment file types'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zca_d_pftyp {
  key mandt : abap.clnt not null;
  key area : zca_param_area_id not null;
  key filetype : abap.char(10) not null;
  singletonid : abap.int1;
  description : abap.char(60);
  processid : abap.char(20);
  direction : abap.char(1);
  acklevel : abap.char(1);
  ackmulti : abap_boolean;
  calendarid : abap.char(2);
  timezone : abap.char(6);
  daycutoff : abap.tims;
  expectedfiles : abap.int4;
  zerook : abap_boolean;
  stalemin : abap.int4;
  opendays : abap.int4;
  active : abap_boolean;
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}

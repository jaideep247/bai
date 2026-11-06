@EndUserText.label : 'Draft: Checks'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zcd_d_hckdef {
  key mandt : abap.clnt not null;
  key checkid : abap.char(20) not null;
  singletonid : abap.int1;
  description : abap.char(60);
  category : abap.char(1);
  classname : abap.char(30);
  active : abap_boolean;
  seq : abap.int4;
  priority : abap.char(1);
  param1 : abap.char(100);
  param2 : abap.char(100);
  param3 : abap.char(100);
  param4 : abap.char(100);
  packagesize : abap.int4;
  timeoutsec : abap.int4;
  changedby : syuname;
  changedat : timestampl;
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}

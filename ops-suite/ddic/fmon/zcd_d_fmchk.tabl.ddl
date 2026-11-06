@EndUserText.label : 'Draft: Checks'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zcd_d_fmchk {
  key mandt : abap.clnt not null;
  key checkid : abap.char(10) not null;
  singletonid : abap.int1;
  classname : abap.char(30);
  severity : abap.char(1);
  active : abap_boolean;
  params : abap.char(255);
  description : abap.char(60);
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}

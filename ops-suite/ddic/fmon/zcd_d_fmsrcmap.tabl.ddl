@EndUserText.label : 'Draft: Status mappings'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zcd_d_fmsrcmap {
  key mandt : abap.clnt not null;
  key srcid : abap.char(10) not null;
  key statusvalue : abap.char(40) not null;
  singletonid : abap.int1;
  stage : abap.char(20);
  info : abap.char(60);
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}

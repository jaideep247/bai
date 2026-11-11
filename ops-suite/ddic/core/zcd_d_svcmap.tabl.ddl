@EndUserText.label : 'Draft: What a business service covers'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zcd_d_svcmap {
  key mandt : abap.clnt not null;
  key service : abap.char(12) not null;
  key area : abap.char(16) not null;
  key matchfield : abap.char(10) not null;
  key matchvalue : abap.char(40) not null;
  singletonid : abap.int1;
  weight : abap.int4;
  active : abap_boolean;
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}

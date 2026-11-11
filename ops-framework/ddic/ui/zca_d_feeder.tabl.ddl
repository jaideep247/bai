@EndUserText.label : 'Draft: Feeder systems of the payment model'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zca_d_feeder {
  key mandt : abap.clnt not null;
  key feeder : abap.char(10) not null;
  singletonid : abap.int1;
  description : abap.char(60);
  urltemplate : abap.char(255);
  refvisible : abap_boolean;
  seq : abap.int4;
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}

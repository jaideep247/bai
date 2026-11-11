@EndUserText.label : 'Draft: Break analysis buckets'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zca_d_brkbkt {
  key mandt : abap.clnt not null;
  key bucket : abap.char(20) not null;
  singletonid : abap.int1;
  description : abap.char(60);
  explained : abap_boolean;
  layerid : abap.char(10);
  seq : abap.int4;
  active : abap_boolean;
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}

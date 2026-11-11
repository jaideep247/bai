@EndUserText.label : 'Draft: Break analysis bucket rules'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zca_d_brkrul {
  key mandt : abap.clnt not null;
  key area : zca_param_area_id not null;
  key ruleid : abap.char(20) not null;
  singletonid : abap.int1;
  layerid : abap.char(10);
  seq : abap.int4;
  bucket : abap.char(20);
  acctpattern : abap.char(70);
  reason : abap.char(120);
  description : abap.char(60);
  active : abap_boolean;
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}

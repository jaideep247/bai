@EndUserText.label : 'Draft: Payment lifecycle stages'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zcd_d_paystage {
  key mandt : abap.clnt not null;
  key stage : abap.char(20) not null;
  singletonid : abap.int1;
  seq : abap.int4;
  label : abap.char(40);
  source : abap.char(10);
  matchvalue : abap.char(30);
  active : abap_boolean;
  stuckdays : abap.int4;
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}

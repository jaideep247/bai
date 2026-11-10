@EndUserText.label : 'Draft: Alert channels'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zca_d_alchn {
  key mandt : abap.clnt not null;
  key channel : abap.char(10) not null;
  singletonid : abap.int1;
  classname : seoclsname;
  destination : abap.char(255);
  active : abap_boolean;
  changedby : syuname;
  changedat : timestampl;
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}

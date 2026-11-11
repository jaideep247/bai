@EndUserText.label : 'Draft: Link registry activation overrides'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zca_d_lnkact {
  key mandt : abap.clnt not null;
  key targetkind : abap.char(1) not null;
  key targetid : abap.char(30) not null;
  singletonid : abap.int1;
  layerid : abap.char(10);
  active : abap_boolean;
  reason : abap.char(60);
  owner : abap.char(30);
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}

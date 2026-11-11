@EndUserText.label : 'Draft: Link registry layers'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zca_d_lnklyr {
  key mandt : abap.clnt not null;
  key layerid : abap.char(10) not null;
  singletonid : abap.int1;
  layerkind : abap.char(1);
  layerrank : abap.int4;
  idprefix : abap.char(10);
  description : abap.char(60);
  owner : abap.char(30);
  active : abap_boolean;
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}

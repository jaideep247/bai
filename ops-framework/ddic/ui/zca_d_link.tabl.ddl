@EndUserText.label : 'Draft: Link registry links'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zca_d_link {
  key mandt : abap.clnt not null;
  key linkid : abap.char(30) not null;
  singletonid : abap.int1;
  layerid : abap.char(10);
  fromobject : abap.char(30);
  toobject : abap.char(30);
  cardinality : abap.char(2);
  quality : abap.char(1);
  fallbackof : abap.char(30);
  replaces : abap.char(30);
  active : abap_boolean;
  owner : abap.char(30);
  verifyref : abap.char(20);
  description : abap.char(60);
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}

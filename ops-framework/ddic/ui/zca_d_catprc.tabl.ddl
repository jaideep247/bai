@EndUserText.label : 'Draft: Process catalogue processes'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zca_d_catprc {
  key mandt : abap.clnt not null;
  key processid : abap.char(20) not null;
  singletonid : abap.int1;
  pkgid : abap.char(10);
  description : abap.char(60);
  component : abap.char(10);
  dashcard : abap.char(20);
  ownerrole : abap.char(40);
  schedule : abap.char(60);
  dfltactive : abap_boolean;
  evidence : abap.char(1);
  verifyref : abap.char(20);
  seq : abap.int4;
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}

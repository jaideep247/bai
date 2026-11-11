@EndUserText.label : 'Draft: Process catalogue activation'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zca_d_catact {
  key mandt : abap.clnt not null;
  key processid : abap.char(20) not null;
  key validfrom : abap.dats not null;
  singletonid : abap.int1;
  active : abap_boolean;
  pkgid : abap.char(10);
  reason : abap.char(80);
  approvedby : syuname;
  approvedon : abap.dats;
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}

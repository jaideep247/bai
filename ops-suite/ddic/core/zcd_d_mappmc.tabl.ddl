@EndUserText.label : 'Draft: Payment method classes (typed ZPMC)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zcd_d_mappmc {
  key mandt : abap.clnt not null;
  key version : abap.numc(4) not null;
  key flow : abap.char(1) not null;
  key paymethod : abap.char(1) not null;
  key housebank : abap.char(5) not null;
  singletonid : abap.int1;
  methodclass : abap.char(3);
  agebasis : abap.char(10);
  calendar : abap.char(2);
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}

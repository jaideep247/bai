@EndUserText.label : 'Draft: Process catalogue steps'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zca_d_catstp {
  key mandt : abap.clnt not null;
  key processid : abap.char(20) not null;
  key stepno : abap.numc(3) not null;
  singletonid : abap.int1;
  stepkind : abap.char(1);
  objname : abap.char(40);
  description : abap.char(60);
  evidence : abap.char(1);
  verifyref : abap.char(20);
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}

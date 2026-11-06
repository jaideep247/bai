@EndUserText.label : 'Draft: Job cycle steps'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zcd_d_jobstep {
  key mandt : abap.clnt not null;
  key cycleid : abap.char(20) not null;
  key stepno : abap.numc(3) not null;
  singletonid : abap.int1;
  description : abap.char(60);
  jobname : abap.char(32);
  program : abap.char(40);
  variant : abap.char(14);
  predstep : abap.numc(3);
  dayoffset : abap.int1;
  windowfrom : abap.tims;
  windowto : abap.tims;
  maxruntimemin : abap.int4;
  skippable : abap_boolean;
  critical : abap_boolean;
  changedby : syuname;
  changedat : timestampl;
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}

@EndUserText.label : 'Draft: Scheduler jobs and SAP job names'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zca_d_jobsch {
  key mandt : abap.clnt not null;
  key schedfolder : abap.char(40) not null;
  key schedjob : abap.char(64) not null;
  singletonid : abap.int1;
  sappattern : abap.char(70);
  criticality : abap.char(1);
  description : abap.char(60);
  active : abap_boolean;
  seq : abap.int4;
  plandays : abap.char(7);
  plantime : abap.tims;
  latemin : abap.int4;
  calendarid : abap.char(2);
  predfolder : abap.char(40);
  predjob : abap.char(64);
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}

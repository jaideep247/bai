@EndUserText.label : 'Draft: Stage deadlines (clock time)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zcd_d_fmdeadl {
  key mandt : abap.clnt not null;
  key ifaceid : abap.char(20) not null;
  key stage : abap.char(20) not null;
  key daytype : abap.char(12) not null;
  singletonid : abap.int1;
  duetime : abap.tims;
  severity : abap.char(1);
  active : abap_boolean;
  description : abap.char(60);
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}

@EndUserText.label : 'Draft: Pilot detection baselines'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zca_d_pilotbl {
  key mandt : abap.clnt not null;
  key area : zca_param_area_id not null;
  key checkid : abap.char(20) not null;
  singletonid : abap.int1;
  baselinemin : abap.int4;
  source : abap.char(60);
  description : abap.char(60);
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}

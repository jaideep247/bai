@EndUserText.label : 'Draft: Business services (health score)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zcd_d_svc {
  key mandt : abap.clnt not null;
  key service : abap.char(12) not null;
  singletonid : abap.int1;
  label : abap.char(60);
  seq : abap.int4;
  weightb : abap.int4;
  weighte : abap.int4;
  weightw : abap.int4;
  stalepoints : abap.int4;
  greenmin : abap.int4;
  ambermin : abap.int4;
  active : abap_boolean;
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}

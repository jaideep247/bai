@EndUserText.label : 'Draft: Flow patterns (XBLNR)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zcd_d_flowpat {
  key mandt : abap.clnt not null;
  key priority : abap.int4 not null;
  key pattern : abap.char(30) not null;
  singletonid : abap.int1;
  flowtype : abap.char(1);
  active : abap_boolean;
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}

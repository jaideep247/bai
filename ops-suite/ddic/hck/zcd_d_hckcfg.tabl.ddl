@EndUserText.label : 'Draft: Health check setup (singleton)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zcd_d_hckcfg {
  key mandt : abap.clnt not null;
  key singletonid : abap.int1 not null;
  lastchangedatmax : abp_lastchange_tstmpl;
  transportrequestid : trkorr;
  "%admin" : include sych_bdl_draft_admin_inc;
}

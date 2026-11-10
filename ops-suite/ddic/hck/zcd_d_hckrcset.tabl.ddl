@EndUserText.label : 'Draft: Reconciliation clearing account sets'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zcd_d_hckrcset {
  key mandt : abap.clnt not null;
  key setid : abap.char(10) not null;
  singletonid : abap.int1;
  kind : abap.char(10);
  side : abap.char(1);
  bukrs : abap.char(4);
  hkont : abap.char(10);
  waers : abap.char(5);
  hbkid : abap.char(5);
  hktid : abap.char(5);
  invertbank : abap_boolean;
  legbank : abap_boolean;
  legfica : abap_boolean;
  tolerance : abap.dec(15,2);
  toleranceset : abap_boolean;
  description : abap.char(60);
  active : abap_boolean;
  changedby : syuname;
  changedat : timestampl;
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}

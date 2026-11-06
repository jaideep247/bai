@EndUserText.label : 'Draft: Returns / NOC lots'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zcd_d_fmlotcfg {
  key mandt : abap.clnt not null;
  key ifaceid : abap.char(20) not null;
  key lottype : abap.char(10) not null;
  singletonid : abap.int1;
  hdrtable : abap.char(30);
  hdrlotfield : abap.char(30);
  hdrlinkfield : abap.char(30);
  itemtable : abap.char(30);
  itemlotfield : abap.char(30);
  itemkeyfield : abap.char(30);
  itemstatusfield : abap.char(30);
  itemlinkfield : abap.char(30);
  linkby : abap.char(1);
  donevalues : abap.char(255);
  nocsladays : abap.int4;
  active : abap_boolean;
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}

@EndUserText.label : 'Draft: Thresholds'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zcd_d_hckthr {
  key mandt : abap.clnt not null;
  key checkid : abap.char(20) not null;
  key metric : abap.char(30) not null;
  key bukrs : abap.char(4) not null;
  singletonid : abap.int1;
  amber : abap.dec(23,4);
  red : abap.dec(23,4);
  higherisworse : abap_boolean;
  baselinemode : abap.char(6);
  zlimit : abap.dec(5,2);
  lookbackruns : abap.int4;
  changedby : syuname;
  changedat : timestampl;
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}

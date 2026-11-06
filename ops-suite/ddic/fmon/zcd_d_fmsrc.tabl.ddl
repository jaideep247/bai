@EndUserText.label : 'Draft: Source adapters'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zcd_d_fmsrc {
  key mandt : abap.clnt not null;
  key srcid : abap.char(10) not null;
  singletonid : abap.int1;
  ifaceid : abap.char(20);
  tablename : abap.char(30);
  filekeyfield : abap.char(30);
  filenamefield : abap.char(30);
  datefield : abap.char(30);
  timefield : abap.char(30);
  tsfield : abap.char(30);
  statusfield : abap.char(30);
  countfield : abap.char(30);
  amountfield : abap.char(30);
  sizefield : abap.char(30);
  checksumfield : abap.char(30);
  sourcefield : abap.char(30);
  lobfield : abap.char(30);
  itemkeyfield : abap.char(30);
  defaultstage : abap.char(20);
  adapterclass : abap.char(30);
  active : abap_boolean;
  description : abap.char(60);
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}

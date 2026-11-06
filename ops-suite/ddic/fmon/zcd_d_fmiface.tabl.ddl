@EndUserText.label : 'Draft: Interfaces'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zcd_d_fmiface {
  key mandt : abap.clnt not null;
  key ifaceid : abap.char(20) not null;
  singletonid : abap.int1;
  direction : abap.char(1);
  filetype : abap.char(10);
  sourcesys : abap.char(10);
  targetsys : abap.char(10);
  paymethod : abap.char(10);
  lob : abap.char(10);
  bankkey : abap.char(15);
  namepattern : abap.char(128);
  minbytes : abap.int8;
  maxbytes : abap.int8;
  ackexpected : abap_boolean;
  acklevel : abap.char(8);
  owner : syuname;
  active : abap_boolean;
  description : abap.char(60);
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}

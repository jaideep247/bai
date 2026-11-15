@EndUserText.label : 'Draft: Account flow accounts by role'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zca_d_flwacc {
  key mandt : abap.clnt not null;
  key area : zca_param_area_id not null;
  key flowid : abap.char(10) not null;
  key flowacct : abap.char(20) not null;
  singletonid : abap.int1;
  role : abap.char(15);
  bukrs : bukrs;
  currency : abap.char(5);
  hkontfrom : saknr;
  hkontto : saknr;
  linesource : abap.char(1);
  seq : abap.int4;
  evalclass : abap.char(30);
  evalcategory : abap.char(10);
  description : abap.char(60);
  active : abap_boolean;
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}

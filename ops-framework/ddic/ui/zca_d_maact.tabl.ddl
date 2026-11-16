@EndUserText.label : 'Draft: Mass activities and their output'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zca_d_maact {
  key mandt : abap.clnt not null;
  key area : zca_param_area_id not null;
  key actid : abap.char(10) not null;
  singletonid : abap.int1;
  description : abap.char(60);
  aktyp : abap.char(10);
  parentprogram : abap.char(40);
  jobpattern : abap.char(70);
  outputkind : abap.char(10);
  minoutput : abap.int4;
  runlimitmin : abap.int4;
  active : abap_boolean;
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}

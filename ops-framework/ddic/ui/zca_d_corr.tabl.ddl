@EndUserText.label : 'Draft: Alert correlation rules'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zca_d_corr {
  key mandt : abap.clnt not null;
  key area : zca_param_area_id not null;
  key corrrule : abap.char(10) not null;
  singletonid : abap.int1;
  description : abap.char(60);
  checkpattern : abap.char(35);
  keyfields : abap.char(60);
  keypattern : abap.char(70);
  windowmin : abap.int4;
  active : abap_boolean;
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}

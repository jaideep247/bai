@EndUserText.label : 'Draft: Payment file milestones'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zca_d_pfstg {
  key mandt : abap.clnt not null;
  key area : zca_param_area_id not null;
  key filetype : abap.char(10) not null;
  key milestone : abap.char(10) not null;
  singletonid : abap.int1;
  description : abap.char(60);
  required : abap_boolean;
  duekind : abap.char(1);
  duetime : abap.tims;
  dayoffset : abap.int4;
  basis : abap.char(10);
  offsetmin : abap.int4;
  gracemin : abap.int4;
  active : abap_boolean;
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}

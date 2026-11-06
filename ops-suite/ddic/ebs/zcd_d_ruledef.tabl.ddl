@EndUserText.label : 'Draft: Rule registry'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zcd_d_ruledef {
  key mandt : abap.clnt not null;
  key ruleid : abap.char(10) not null;
  singletonid : abap.int1;
  rulelevel : abap.char(1);
  classname : seoclsname;
  defaultseverity : abap.char(1);
  defaultaction : abap.char(10);
  description : abap.char(60);
  active : abap_boolean;
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}

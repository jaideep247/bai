@EndUserText.label : 'Draft: Account flow stage rules'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zca_d_flwrul {
  key mandt : abap.clnt not null;
  key area : zca_param_area_id not null;
  key flowid : abap.char(10) not null;
  key ruleseq : abap.numc(4) not null;
  singletonid : abap.int1;
  ruleid : abap.char(20);
  stageid : abap.char(20);
  linesource : abap.char(1);
  reftype : abap.char(5);
  doctype : abap.char(2);
  origin : abap.char(2);
  maintrans : abap.char(4);
  subtrans : abap.char(4);
  debitcredit : abap.char(1);
  description : abap.char(60);
  active : abap_boolean;
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}

@EndUserText.label : 'Draft: Alert rules'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zcd_d_alrule {
  key mandt : abap.clnt not null;
  key ruleid : abap.char(10) not null;
  singletonid : abap.int1;
  paymentenginearea : abap.char(4);
  minseverity : abap.char(1);
  rulepattern : abap.char(35);
  checkpattern : abap.char(35);
  group1pattern : abap.char(35);
  group2pattern : abap.char(35);
  minrag : abap.char(1);
  onabort : abap_boolean;
  channel : abap.char(10);
  destination : abap.char(255);
  digest : abap_boolean;
  maxitems : abap.int4;
  throttlemin : abap.int4;
  quietfrom : abap.tims;
  quietto : abap.tims;
  escalateafter : abap.int4;
  escalationdest : abap.char(255);
  escoverride : abap_boolean;
  active : abap_boolean;
  changedby : syuname;
  changedat : timestampl;
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}

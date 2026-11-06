@EndUserText.label : 'Draft: House bank accounts'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zcd_d_ebsacct {
  key mandt : abap.clnt not null;
  key bukrs : abap.char(4) not null;
  key hbkid : abap.char(5) not null;
  key hktid : abap.char(5) not null;
  singletonid : abap.int1;
  accountno : abap.char(35);
  bankkey : abap.char(15);
  format : abap.char(8);
  flowdefault : abap.char(1);
  currency : abap.char(5);
  glaccount : abap.char(10);
  active : abap_boolean;
  lastchangedby : abp_lastchange_user;
  lastchangedat : abp_lastchange_tstmpl;
  locallastchangedat : abp_locinst_lastchange_tstmpl;
  "%admin" : include sych_bdl_draft_admin_inc;
}

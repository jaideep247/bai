@EndUserText.label : 'Ops framework: account flow tiles'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zca_ops_flwtil {
  key mandt     : abap.clnt not null;
  key area      : zca_param_area_id not null;
  key flow_id   : abap.char(10) not null;
  // Tile above the matrix fed by stage rows: REQUESTED, PAID (paid / settled by the bank), CLEARED (matched and
  // cleared); every row adds the debit (D) or credit (C) of one stage on the accounts of one role - so one stage can
  // feed two tiles on two roles (a bank statement pays out of cash and clears the clearing account)
  key tile      : abap.char(10) not null;
  key stage_id  : abap.char(20) not null;
  key role      : abap.char(15) not null;
  side          : abap.char(1);
  description   : abap.char(60);
  active        : abap_boolean;
  // RAP configuration app: set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}

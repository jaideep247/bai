@EndUserText.label : 'Ops framework: account flow stages'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zca_ops_flwstg {
  key mandt     : abap.clnt not null;
  key area      : zca_param_area_id not null;
  key flow_id   : abap.char(10) not null;
  // Row of the dashboard: one posting stage (payment request posted, payment run, bank statement, ...); OTHER,
  // MOVEMENT, OPENING, CLOSING and UNEXPLAINED are reserved rows of the dashboard
  key stage_id  : abap.char(20) not null;
  // Order of the rows
  seq           : abap.int4;
  description   : abap.char(60);
  // Expected postings (brackets): the stage will post what the checks hold open on the accounts of role
  // EXPECT_FROM (it clears them) against the accounts of role EXPECT_TO - e.g. a returns lot clears the returns
  // clearing account (CLARIFICATION) and reopens the payable (PAYABLE)
  expect_from   : abap.char(15);
  expect_to     : abap.char(15);
  active        : abap_boolean;
  // RAP configuration app: set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}

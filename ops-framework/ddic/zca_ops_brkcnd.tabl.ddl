@EndUserText.label : 'Ops framework: break analysis rule conditions'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zca_ops_brkcnd {
  key mandt     : abap.clnt not null;
  key area      : zca_param_area_id not null;
  key rule_id   : abap.char(20) not null;
  key cond_no   : abap.numc(3) not null;
  // FIELD = a field of the open line, GROUP = a value of its group (assignment and currency), DAYS = a day window,
  // LINK = a linked object read through the link registry (LINK_ID); every condition of a rule must hold
  cond_kind     : abap.char(5);
  // FIELD / GROUP: the line or group value (ZIF_CA_OPS_BRK_TYPES=>GC_FIELD); DAYS: PERIOD_END (days to the end of
  // the posting month) or KEY_DATE (days before the key date); LINK: field of the linked object
  field         : abap.char(30);
  // EQ NE IN NI GE LE GT LT RX (PCRE, complete value) BL (blank) NB (not blank); LINK: EX / NX (a linked row with
  // the value exists / none exists)
  operator      : abap.char(2);
  // Value, comma list (IN / NI / EX / NX) or @PARAMETER (a value list of area CA_OPS, e.g. bank transaction codes)
  cond_value    : abap.char(120);
  // LINK: link of the registry from the line's object (journal entry line) to the object read
  link_id       : abap.char(30);
  // LINK with EX: linked rows with the value needed at least (0 = 1), e.g. two paid codes on one cheque
  min_count     : abap.int4;
  // RAP configuration app: set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}

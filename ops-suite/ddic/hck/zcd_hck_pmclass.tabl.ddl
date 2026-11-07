@EndUserText.label : 'Health check: payment method classes (in flight)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zcd_hck_pmclass {
  key mandt        : abap.clnt not null;
  // D disbursement / C collection (TFK042Z-XEINZ of the payment method)
  key flow         : abap.char(1) not null;
  // open list of configuration (e.g. WIR, ACH, CHQ, CRD); flow + class = threshold key
  key method_class : abap.char(3) not null;
  // SAP payment methods of the class, comma list (one method in one class per flow)
  pay_methods      : abap.char(40);
  // VALUE_DATE: business days after the value date; ISSUE_DATE: calendar days after issue
  age_basis        : abap.char(10);
  // factory calendar of the business days (blank = PARAM1 of A_INFLIGHT); per bank: ZCD_HCK_PMBANK
  calendar         : abap.char(2);
  description      : abap.char(60);
  // blank: the class is not watched (rows are created only by transport, D-3)
  active           : abap_boolean;
  changed_by       : syuname;
  changed_at       : timestampl;
  // RAP configuration apps (design 5): set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}

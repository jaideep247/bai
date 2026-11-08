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
  // blank = the class row (all house banks: payment methods, ageing basis, calendar);
  // a house bank (DPAYH-HBKID) = only the factory calendar of that bank for the class, e.g. UK /
  // German bank holidays (table consolidation 2026-11-08, was ZCD_HCK_PMBANK)
  key hbkid        : abap.char(5) not null;
  // SAP payment methods of the class, comma list (one method in one class per flow); class row only
  pay_methods      : abap.char(40);
  // VALUE_DATE: business days after the value date; ISSUE_DATE: calendar days after issue; class row only
  age_basis        : abap.char(10);
  // factory calendar of the business days: class row blank = PARAM1 of A_INFLIGHT; house-bank row
  // required, overrides the class calendar for payments of that house bank
  calendar         : abap.char(2);
  description      : abap.char(60);
  // blank: the class (or the bank override) is not used (rows are created only by transport, D-3)
  active           : abap_boolean;
  changed_by       : syuname;
  changed_at       : timestampl;
  // RAP configuration apps (design 5): set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}
// Read once per run, all active rows (ZCL_CD_HCK_RUNTIME_DAO=>GET_PM_CLASSES); the payment outcome
// maps payment methods by the class rows only (HBKID blank), so a method stays in exactly one class.

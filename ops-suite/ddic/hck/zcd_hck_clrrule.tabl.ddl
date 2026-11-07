@EndUserText.label : 'Health check: clearing / return evidence rules'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zcd_hck_clrrule {
  key mandt        : abap.clnt not null;
  key flow         : abap.char(1) not null;
  // ZCD_HCK_PMCLASS-METHOD_CLASS
  key method_class : abap.char(3) not null;
  // VOIDED / RETURNED / PENDING / CLEARED / IN_FLIGHT (first purpose with evidence decides)
  key purpose      : abap.char(10) not null;
  key seq          : abap.numc(3) not null;
  // plug-in class implementing ZIF_CD_HCK_EVIDENCE
  evidence_class   : abap.char(30);
  // parameters of the evidence kind (status values, suffix length, outcomes, G/L accounts)
  param1           : abap.char(40);
  param2           : abap.char(40);
  param3           : abap.char(40);
  // X must hold (indicates), C must hold (condition), N must not hold, blank shown only; AND
  required         : abap.char(1);
  description      : abap.char(60);
  active           : abap_boolean;
  changed_by       : syuname;
  changed_at       : timestampl;
  // RAP configuration apps (design 5): set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}

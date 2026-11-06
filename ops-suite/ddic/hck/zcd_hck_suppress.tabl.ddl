@EndUserText.label : 'HCK: temporary suppression of known findings'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #DISPLAY
define table zcd_hck_suppress {
  key mandt             : abap.clnt not null;
  key suppress_uuid     : sysuuid_x16 not null;
  check_id              : abap.char(20);
  // Pattern on the finding's object key (blank = every finding of the check), e.g. HCK_A01/*/US01
  key_pattern           : abap.char(70);
  // Company code the suppression is limited to (blank = all); matched inside the object key
  bukrs                 : abap.char(4);
  valid_from            : abap.dats;
  valid_to              : abap.dats;
  reason                : abap.char(255);
  // A = active; R = longer than HCK_SUPPRESS_MAX_DAYS, waiting for a second user
  status                : abap.char(1);
  created_by            : syuname;
  created_at            : timestampl;
  approved_by           : syuname;
  approved_at           : timestampl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
  last_changed_at       : abp_lastchange_tstmpl;
}
// Secondary index ZCD_HCK_SUPPRESS~ACT : MANDT, STATUS, VALID_TO (active suppressions of a run)

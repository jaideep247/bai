@EndUserText.label : 'EBS: blocked bank statement line releases'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #DISPLAY
define table zcd_ebs_release {
  key mandt             : abap.clnt not null;
  key release_uuid      : sysuuid_x16 not null;
  // Line finding released: OBJECT_KEY of the finding (<statement key>/<line no>) + check code;
  // a different block finding on the same line still blocks
  object_key            : abap.char(70);
  check_code            : abap.char(30);
  bukrs                 : abap.char(4);
  reason                : abap.char(255);
  evidence              : abap.char(255);
  // R = requested, A = approved (second user), X = rejected
  status                : abap.char(1);
  requested_by          : syuname;
  requested_at          : timestampl;
  approved_by           : syuname;
  approved_at           : timestampl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
  last_changed_at       : abp_lastchange_tstmpl;
}
// Secondary index OBJ: posting gate lookup
// @index OBJ: MANDT, OBJECT_KEY, CHECK_CODE, STATUS

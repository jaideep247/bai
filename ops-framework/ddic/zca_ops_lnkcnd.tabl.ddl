@EndUserText.label : 'Ops framework: link registry link conditions'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zca_ops_lnkcnd {
  key mandt   : abap.clnt not null;
  key link_id : abap.char(30) not null;
  key cond_no : abap.numc(3) not null;
  // EQ to field = from field (transformed); CONST to field = value (comma list = IN); NOTINIT to field filled;
  // PREFER of several rows of one source row keep those with to field = value (e.g. a status SUCCESS)
  cond_kind     : abap.char(8);
  // TABLE-FIELD of the from object (EQ only) and of the to object; checked on save against the runtime DDIC
  from_ref      : abap.char(61);
  to_ref        : abap.char(61);
  // Literal of CONST / PREFER: quoted by CL_ABAP_DYN_PRG, never concatenated raw
  cond_value    : abap.char(70);
  // EQ only, applied to the from value: ALPHA (leading zeros to length ARG), NOZERO, UPPER, LEFT / RIGHT (ARG
  // characters), PREFIX / SUFFIX (ARG text)
  transform     : abap.char(6);
  transform_arg : abap.char(20);
  // RAP configuration app: set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}

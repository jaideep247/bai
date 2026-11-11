@EndUserText.label : 'Ops suite: what a business service covers'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zcd_ops_svcmap {
  key mandt       : abap.clnt not null;
  key service     : abap.char(12) not null;
  // Area of the findings (parameter area of ZCA_PARAM, e.g. CD_FMON); for CONTROL the area of the control
  key area        : abap.char(16) not null;
  // AREA = every finding of the area; CONTROL = the checks a control of the daily review covers (its covered-check
  // rows, ZCA_OPS_CTLCHK); RULE_ID / CHECK_CODE / GROUP2 = findings whose field equals MATCH_VALUE
  key match_field : abap.char(10) not null;
  // Exact value (control ID, rule ID, check code or check ID; blank for AREA). Joined in CDS, so no pattern - as
  // the covered-check rows of the framework; list several codes as several rows
  key match_value : abap.char(40) not null;
  // Multiplier of the severity points of a finding caught by this row (a finding caught twice counts once, with
  // the highest weight)
  weight          : abap.int4;
  active          : abap_boolean;
  // RAP configuration apps (design 5): set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}
// Read only by CDS (ZI_CD_SvcRule). Delivered rows: config/service_map.csv. New rows only by transport (DV1).

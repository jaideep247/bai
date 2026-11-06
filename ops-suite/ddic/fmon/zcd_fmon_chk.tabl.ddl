@EndUserText.label : 'FMON: plug-in checks (SM30)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zcd_fmon_chk {
  key mandt    : abap.clnt not null;
  // Written to ZCD_OPS_FINDING-RULE_ID
  key check_id : abap.char(10) not null;
  // Class implementing ZIF_CD_FMON_CHECK
  class_name   : abap.char(30);
  // Default severity of the check's findings (B/E/W/I)
  severity     : abap.char(1);
  active       : abap_boolean;
  // NAME=VALUE;NAME2=VALUE2, e.g. GRACE_MIN=60, STAGE=SENT_TO_PRISM, TOLERANCE=0.01
  params       : abap.char(255);
  description  : abap.char(60);
  // RAP configuration apps (design 5): set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}

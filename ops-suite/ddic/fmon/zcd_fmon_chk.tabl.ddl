@EndUserText.label : 'FMON: plug-in checks (SM30)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zcd_fmon_chk {
  key client   : abap.clnt not null;
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
}

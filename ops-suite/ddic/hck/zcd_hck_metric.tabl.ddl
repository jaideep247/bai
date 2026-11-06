@EndUserText.label : 'Health check: metric history (baselines, trends)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #DISPLAY
define table zcd_hck_metric {
  key client    : abap.clnt not null;
  key run_id    : sysuuid_x16 not null;
  key check_id  : abap.char(20) not null;
  key metric    : abap.char(30) not null;
  key dim1      : abap.char(35) not null;
  key dim2      : abap.char(35) not null;
  value         : abap.dec(31,4);
  measured_at   : timestampl;
}
// Secondary index ZCD_HCK_METRIC~HST: CLIENT, CHECK_ID, METRIC, DIM1, MEASURED_AT (baseline history)
// Secondary index ZCD_HCK_METRIC~TIM: CLIENT, MEASURED_AT (dashboard trend, archiving/deletion)
// Retention: delete rows older than ZCD_OPS_PARAM HCK_METRIC_KEEP_DAYS (housekeeping job, later phase).

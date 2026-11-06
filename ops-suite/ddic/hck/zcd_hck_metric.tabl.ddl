@EndUserText.label : 'Health check: metric history (baselines, trends)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #DISPLAY
define table zcd_hck_metric {
  key mandt     : abap.clnt not null;
  key run_id    : sysuuid_x16 not null;
  key check_id  : abap.char(20) not null;
  key metric    : abap.char(30) not null;
  key dim1      : abap.char(35) not null;
  key dim2      : abap.char(35) not null;
  value         : abap.dec(31,4);
  measured_at   : timestampl;
  // A88: V volume (SUM), L level - duration / age / size (MAX, AVG), R rate (weighted)
  kind          : abap.char(1);
  // rates: denominator the rate was computed over; weighted rate = SUM(value*weight)/SUM(weight)
  weight        : abap.dec(31,4);
}
// Secondary index HST: baseline history; TIM: dashboard trend, archiving / deletion
// @index HST: MANDT, CHECK_ID, METRIC, DIM1, MEASURED_AT
// @index TIM: MANDT, MEASURED_AT
// Retention: delete rows older than ZCD_OPS_PARAM HCK_METRIC_KEEP_DAYS (housekeeping job, later phase).

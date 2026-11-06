@EndUserText.label : 'FMON: expected files per day type (SM30)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zcd_fmon_cal {
  key mandt      : abap.clnt not null;
  key iface_id   : abap.char(20) not null;
  // NORMAL, MONTH_END, HOLIDAY, RETURNS_DAY (MONTH_END/RETURNS_DAY fall back to NORMAL; HOLIDAY does not)
  key day_type   : abap.char(12) not null;
  expected_count : abap.int4;
  // Window in the time zone of parameter FMON_TIME_ZONE; window_to < window_from crosses midnight
  window_from    : abap.tims;
  window_to      : abap.tims;
  // Factory calendar (TFACD); blank = parameter FMON_FACTORY_CAL
  fcal_id        : abap.char(2);
}

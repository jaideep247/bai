@EndUserText.label : 'Ops framework: planned downtime windows'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #DISPLAY
define table zca_ops_dtwin {
  key mandt     : abap.clnt not null;
  key window_id : sysuuid_x16 not null;
  // Area of the window (a parameter area of ZCA_PARAM); a window covers findings of this area only
  area          : zca_param_area_id;
  // Optional scope, PCRE matched to the complete value, case ignored; blank = any. All filled patterns
  // must match: check code, object key, interface or bank (GROUP1 or GROUP2 of the finding)
  check_pattern : abap.char(35);
  object_pattern : abap.char(70);
  group_pattern : abap.char(35);
  // Start and end as entered: local date and time in TIME_ZONE (parameter DOWNTIME_TIME_ZONE at creation)
  from_date     : abap.dats;
  from_time     : abap.tims;
  to_date       : abap.dats;
  to_time       : abap.tims;
  time_zone     : tznzone;
  // The same start and end in UTC, set on save from the entry and the row's own time zone: what the store,
  // the alert router and the downtime API compare (index ARE)
  from_utc      : timestampl;
  to_utc        : timestampl;
  reason        : abap.char(255);
  created_by    : syuname;
  created_at    : timestampl;
  // Four-eyes: approved by a second user with ZCA_OPS 85 for the area; only approved windows take effect
  approved_by   : syuname;
  approved_at   : timestampl;
  // Ended early by a user (action End now: the end set to the time of the action)
  ended_by      : syuname;
  // ETag of the downtime app (UTC)
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}
// Written only by the downtime app ZUI_CA_OPS_DTW (ZR_CA_OpsDowntime). A window ends by itself at TO (status
// derived, never stored). Retention: ZCA_OPS_RETENTION target DOWNTIME (DOWNTIME_RETENTION_DAYS, by TO_UTC).
// Secondary index ARE: windows of an area by their end (store, alert router, downtime API)
// @index ARE: MANDT, AREA, TO_UTC

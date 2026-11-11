@EndUserText.label : 'Ops framework: SAP job monitor watermark'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #DISPLAY
define table zca_ops_jobwm {
  key mandt     : abap.clnt not null;
  key area      : zca_param_area_id not null;
  key check_id  : abap.char(20) not null;
  // End of the last window read completely (server date and time of TBTCO); the next run reads from
  // here minus JOB_OVERLAP_MIN
  wm_date       : abap.dats;
  wm_time       : abap.tims;
  run_id        : sysuuid_x16;
}
// One row per area and check of the job monitor; written in the run's LUW (never in test mode), never purged.

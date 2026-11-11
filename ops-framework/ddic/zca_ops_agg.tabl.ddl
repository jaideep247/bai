@EndUserText.label : 'Ops framework: no-code aggregate checks'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zca_ops_agg {
  key mandt     : abap.clnt not null;
  key area      : zca_param_area_id not null;
  // Check of the registry (ZCA_OPS_CHECK with class ZCL_CA_OPS_CHK_AGG); one check may hold several rows
  key check_id  : abap.char(20) not null;
  // RULE_ID of the findings of this row
  key agg_id    : abap.char(10) not null;
  description   : abap.char(60);
  // Table read (approved for the area in ZCA_OPS_TABWL, S_TABU_NAM display); every field is checked against
  // the runtime DDIC of this table; aggregated on the database (COUNT / MIN), never row by row
  tabname       : abap.char(30);
  // COUNT = rows matching the conditions; AGE = days since the oldest DATE_FIELD of the matching rows
  agg_func      : abap.char(5);
  // DATS field: AGE counts from it; COUNT with a DATE_FIELD counts only rows at least MIN_AGE_DAYS old
  date_field    : abap.char(30);
  min_age_days  : abap.int4;
  // Window (2026-11-11): only rows with a DATE_FIELD at most MAX_AGE_DAYS old (0 = no window), e.g. the
  // write-offs of the last day
  max_age_days  : abap.int4;
  // TIMS field next to DATE_FIELD: a check that measures a time window (planned downtime) compares date and time
  time_field    : abap.char(30);
  // Company-code field of the table: one result (and finding) per company code, finding BUKRS = its value;
  // blank = one area-level result. Required when the check is BUKRS_AWARE
  bukrs_field   : abap.char(30);
  // Status condition: EQ NE IN NI (IN / NI: comma list, NI = none of them); values are quoted, never concatenated raw
  status_field  : abap.char(30);
  status_op     : abap.char(2);
  status_value  : abap.char(70);
  // Optional second condition: EQ NE GT LT GE LE IN NI
  cond_field    : abap.char(30);
  cond_op       : abap.char(2);
  cond_value    : abap.char(70);
  // Thresholds of the result (rows or days; 0 = not set): >= RED error (exception), >= AMBER warning
  amber         : abap.int4;
  red           : abap.int4;
  // Check code of the findings (blank = AGG_COUNT / AGG_AGE)
  check_code    : abap.char(30);
  active        : abap_boolean;
  // RAP configuration app: set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}
// Read by ZCL_CA_OPS_CHECK_DAO=>GET_AGGREGATES (area, check, active). The table read needs an index that starts
// with the status field (and the company-code field) - VERIFY-SE11 per approved table (docs/VERIFY.md V48).

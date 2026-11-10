@EndUserText.label : 'Ops framework: daily control review (sign-off)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #DISPLAY
define table zca_ops_review {
  key mandt     : abap.clnt not null;
  key area      : zca_param_area_id not null;
  key control_id : abap.char(20) not null;
  // Business date reviewed (local date of the parameter CONTROL_TIME_ZONE)
  key business_date : abap.dats not null;
  // Company code of the reviewed slice (2026-11-10, company-code isolation): blank = the area-level slice
  // (findings without company code and the run evidence); a company code = the findings of that company
  // code only - each slice is signed off by a reviewer authorised for it (ZCA_OPS 02 with BUKRS)
  key bukrs     : bukrs not null;
  // Derived status when the reviewer signed off: H healthy, W watch, A action required
  status_at_review : zca_ops_ctl_status;
  // Result the reviewer confirmed (differs from STATUS_AT_REVIEW only with an observation)
  review_result : zca_ops_ctl_status;
  // Evidence: the latest run of the control's checks on the business date when signed off
  evidence_run  : sysuuid_x16;
  reviewed_by   : syuname;
  // UTC; shown in the time zone of CONTROL_TIME_ZONE
  reviewed_at   : timestampl;
  // Mandatory for action required, and when the result differs from the derived status
  observation   : abap.char(255);
  next_action   : abap.char(255);
  // ETag of the review app (UTC, set by every sign-off)
  last_changed_at : timestampl;
}
// Written only by the review app ZUI_CA_OPS_REV (action markReviewed, ZCL_CA_OPS_REVIEW_DAO). No counts and
// no copies: status, exception count and evidence are derived from the findings when shown.
// Retention: ZCA_OPS_RETENTION target REVIEW (RETENTION_DAYS_REVIEW, area CA_OPS, 400 days).

@EndUserText.label : 'Ops framework: payment file milestones'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zca_ops_pfstg {
  key mandt     : abap.clnt not null;
  key area      : zca_param_area_id not null;
  key file_type : abap.char(10) not null;
  // Milestone of the lifecycle that applies to the file type: PAYRUN, GENERATED, PICKUP, DELIVERED, RECEIPT,
  // ACCEPTED, SETTLED (product vocabulary; receipt by the bank and acceptance by the bank are never one milestone)
  key milestone : abap.char(10) not null;
  description   : abap.char(60);
  // X = the milestone must be reached (a missing one past its deadline is a finding); blank = shown when observed
  required      : abap_boolean;
  // Deadline: T = clock time DUE_TIME (local time of the file type) DAY_OFFSET business days after the business
  // date; O = OFFSET_MIN minutes after the milestone BASIS was reached; blank = no deadline
  due_kind      : abap.char(1);
  due_time      : abap.tims;
  day_offset    : abap.int4;
  basis         : abap.char(10);
  offset_min    : abap.int4;
  // Minutes overdue before the finding is an error (warning until then; 0 = parameter PF_GRACE_MIN)
  grace_min     : abap.int4;
  active        : abap_boolean;
  // RAP configuration app: set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}
// The order of the milestones is the product's (ZIF_CA_OPS_PF_TYPES=>GC_MILESTONE); a site chooses which apply.

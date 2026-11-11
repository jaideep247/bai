@EndUserText.label : 'Ops framework: runbook link per check'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zca_ops_runbook {
  key mandt     : abap.clnt not null;
  // Area of the findings (a parameter area of ZCA_PARAM; authorisation ZCA_OPS per area)
  key area      : zca_param_area_id not null;
  // Field of the finding compared: RULE_ID, CHECK_CODE or GROUP2 (exact value, as a control's covered checks)
  key match_field : abap.char(10) not null;
  key match_value : abap.char(35) not null;
  // Runbook page of the check (http / https, checked on save while the row is active)
  runbook_url   : abap.char(255);
  // The one thing to do first, shown with the link (exceptions app, alert e-mail)
  first_action  : abap.char(120);
  // X = shown; a row with a placeholder link stays inactive until the site's link is entered
  active        : abap_boolean;
  // RAP configuration app: set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}
// Exact values, not patterns: the link of a finding is joined in CDS (ZI_CA_OpsFindRunbook, exceptions app and
// other apps) - CHECK_CODE before GROUP2 before RULE_ID when several rows match. Read by the alert router (DAO).
// New rows only by transport (DV1).

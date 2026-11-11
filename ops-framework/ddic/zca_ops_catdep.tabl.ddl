@EndUserText.label : 'Ops framework: process catalogue dependencies'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zca_ops_catdep {
  key mandt      : abap.clnt not null;
  key process_id : abap.char(20) not null;
  // The process this one depends on (a process of the same or a lower package)
  key pred_id    : abap.char(20) not null;
  // H hard: needs the predecessor active and run first (the onboarding check reports an inactive predecessor);
  // S soft: uses data of the predecessor when it is active
  dep_kind       : abap.char(1);
  description    : abap.char(60);
  // RAP configuration app: set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}

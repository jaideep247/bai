@EndUserText.label : 'EBS: rule registry (rule id -> class)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zcd_ebs_rule_def {
  key mandt        : abap.clnt not null;
  key rule_id      : abap.char(10) not null;
  // S statement / L line
  rule_level       : abap.char(1);
  // Implements ZIF_CD_EBS_RULE
  class_name       : seoclsname;
  default_severity : abap.char(1);
  default_action   : abap.char(10);
  description      : abap.char(60);
  active           : abap_boolean;
  // Operating model 2026-11-06: reads SAP evidence of the posting / clearing - not evaluated
  // for an imported entry that is expected to post but is not posted (POSTING_INCOMPLETE)
  needs_posting    : abap_boolean;
  // Dashboard class of the rule's findings (ZI_CD_EbsFinding): DUPLICATE, POSTING (posting
  // incomplete) or blank; ZIF_CD_EBS_TYPES=>GC_FINDING_CLASS, checked in the configuration app
  finding_class    : abap.char(10);
  // RAP configuration apps (design 5): set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}

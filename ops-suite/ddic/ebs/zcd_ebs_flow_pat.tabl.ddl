@EndUserText.label : 'EBS: flow derivation by XBLNR pattern'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zcd_ebs_flow_pat {
  key mandt    : abap.clnt not null;
  key priority : abap.int4 not null;
  // CP pattern on FEBEP-XBLNR (ported from ZB_BAI_GL_CONFIG)
  key pattern  : abap.char(30) not null;
  flow_type    : abap.char(1);
  active       : abap_boolean;
  // RAP configuration apps (design 5): set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}

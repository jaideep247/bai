@EndUserText.label : 'Health check: expected groups per aggregate'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zcd_hck_agggrp {
  key mandt       : abap.clnt not null;
  key check_id    : abap.char(20) not null;
  // ZCD_HCK_AGG row whose GROUP_FIELD values are expected (audit A103)
  key agg_id      : abap.char(10) not null;
  // expected value of GROUP_FIELD (e.g. company code); no rows for it = measured 0
  key group_value : abap.char(70) not null;
  description     : abap.char(60);
  changed_by      : syuname;
  changed_at      : timestampl;
  // RAP configuration apps (design 5): set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}

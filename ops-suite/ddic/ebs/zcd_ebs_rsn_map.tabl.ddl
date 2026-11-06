@EndUserText.label : 'EBS: NACHA return/NOC reason to FI-CA'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zcd_ebs_rsn_map {
  key mandt   : abap.clnt not null;
  // R01..R85 or C01..C07
  key reason  : abap.char(4) not null;
  // FI-CA return reason (returns lot)
  fica_reason : abap.char(3);
  is_noc      : abap_boolean;
  // RAP configuration apps (design 5): set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}

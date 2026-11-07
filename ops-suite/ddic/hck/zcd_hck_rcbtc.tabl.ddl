@EndUserText.label : 'Health check: bank code role per reconciliation set'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zcd_hck_rcbtc {
  key mandt    : abap.clnt not null;
  // ZCD_HCK_RCSET-SET_ID
  key set_id   : abap.char(10) not null;
  // BAI2 type code of the bank line (FEBEP-VORGC)
  key btc_code : abap.char(10) not null;
  // LEG compared / DEPOSIT Stripe payout deposit / CUTOFF return or retrieval of the next period /
  // REDEPOSIT failure with delayed redeposit / CHEQUE cheque exception / OTHER explained variance /
  // IGNORE no money of the set; a code without row is unmapped (variance, listed)
  role         : abap.char(10);
  description  : abap.char(60);
  active       : abap_boolean;
  changed_by   : syuname;
  changed_at   : timestampl;
  // RAP configuration apps (design 5): set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}

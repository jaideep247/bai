@EndUserText.label : 'Health check: bank code roles (lifecycle and reconciliation)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zcd_hck_btcrole {
  key mandt        : abap.clnt not null;
  // LIFECYCLE: role of a code in the payment lifecycle (A_INFLIGHT, payment outcome);
  // RECON: role of a code in a reconciliation set (A_RECON_3WAY; was ZCD_HCK_RCBTC, 2026-11-08)
  key usage        : abap.char(10) not null;
  // What the role belongs to: LIFECYCLE = flow + method class (e.g. DACH, the 4-character threshold
  // key: flow D / C + ZCD_HCK_PMCLASS-METHOD_CLASS); RECON = set id (ZCD_HCK_RCSET-SET_ID)
  key scope        : abap.char(10) not null;
  // BAI2 / ISO / PRTRY (as ZCD_BTC_MAP); from the statement format (FEBEP-VORGC or VGEXT);
  // RECON rows: BAI2 (FEBEP-VORGC of the set's account)
  key scheme       : abap.char(5) not null;
  // code in the scheme; the same code means different things per scope
  key btc_code     : abap.char(35) not null;
  // LIFECYCLE: open list of configuration (e.g. ORIGINAL, RETURNED, COLLECTED, COLLECT_FAIL);
  // RECON: LEG compared / DEPOSIT Stripe payout deposit / CUTOFF return or retrieval of the next
  // period / REDEPOSIT failure with delayed redeposit / CHEQUE cheque exception / OTHER explained
  // variance / IGNORE no money of the set; a code without row is unmapped (variance, listed).
  // The values of one usage are refused for the other (configuration app, message 424).
  role             : abap.char(15);
  // LIFECYCLE only (blank for RECON): X the amount of a line of this role is compared with the
  // returns lot (DFKKRP), R with the payment amount of the cheque (DPAYH via DFKKCR-DOC1R = AUGBL),
  // C correction (supersedes an earlier R amount), blank not compared
  compare_amount   : abap.char(1);
  description      : abap.char(60);
  active           : abap_boolean;
  changed_by       : syuname;
  changed_at       : timestampl;
  // RAP configuration apps (design 5): set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}
// Read by key prefix USAGE (+ SCOPE): ZCL_CD_HCK_RUNTIME_DAO=>GET_BTC_ROLES (LIFECYCLE, flow and method
// class split from SCOPE), ZCL_CD_HCK_RECON_DAO=>GET_BTC_ROLES (RECON, BAI2). New rows only on a
// customizing request in DV1 (D-3). Example rows: config/hck_seed.md section 8e (LIFECYCLE), 10b (RECON).

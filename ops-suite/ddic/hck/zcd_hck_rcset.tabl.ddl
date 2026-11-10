@EndUserText.label : 'Health check: three-way reconciliation clearing account sets'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zcd_hck_rcset {
  key mandt    : abap.clnt not null;
  // reconciliation set (one transit / clearing account in one currency)
  key set_id   : abap.char(10) not null;
  // THREEWAY bank / G/L / payment engine per day, ACH_ZUONR also one-to-one by assignment,
  // STRIPE descriptor group = BAI deposit + fees
  kind         : abap.char(10);
  // C collections / D disbursements (TFK042Z-XEINZ side of the account)
  side         : abap.char(1);
  bukrs        : abap.char(4);
  // transit / clearing G/L account (ACDOCA-RACCT, DFKKSUMC-HKONT)
  hkont        : abap.char(10);
  // currency of the group (bank line currency, ACDOCA-RWCUR, DFKKSUMC-WAERS)
  waers        : abap.char(5);
  // house bank account: ZCD_EBS_ACCT row (BUKRS, HBKID, HKTID) whose ACCOUNT_NO scopes the bank
  // lines by the payment engine account in FEBEP-XBLNR (as EBS)
  hbkid        : abap.char(5);
  hktid        : abap.char(5);
  // leg mapping: X = bank credit is a G/L debit of the clearing account inverted
  invert_bank  : abap_boolean;
  // leg mapping: X = bank leg compared with the G/L leg (bank <-> G/L)
  leg_bank     : abap_boolean;
  // leg mapping: X = G/L leg compared with the payment engine control total (G/L <-> subledger)
  leg_fica     : abap_boolean;
  // absolute tolerance in the set currency; used when TOLERANCE_SET = X (0.00 = exact match), else the
  // parameter HCK_RECON_TOLERANCE (a value above 0 without the flag also counts as maintained)
  tolerance    : abap.dec(15,2);
  // X = TOLERANCE of the set is maintained (2026-11-10: 0.00 with the flag is an exact match)
  tolerance_set : abap_boolean;
  description  : abap.char(60);
  active       : abap_boolean;
  changed_by   : syuname;
  changed_at   : timestampl;
  // RAP configuration apps (design 5): set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}
// Read by ZCL_CD_HCK_RECON_DAO (check A_RECON_3WAY, ZCL_CD_HCK_C_RECON3); new rows only on a
// customizing request in DV1 (D-3). Example rows: config/hck_seed.md section 10.

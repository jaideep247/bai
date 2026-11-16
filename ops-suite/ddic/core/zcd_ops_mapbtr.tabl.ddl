@EndUserText.label : 'Ops suite: typed mapping - bank code roles (ZBTR)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zcd_ops_mapbtr {
  key mandt       : abap.clnt not null;
  // Mapping version: the reader reads the version of parameter POSTAREA_VERSION_BTR
  key version     : abap.numc(4) not null;
  // LIFECYCLE (A_INFLIGHT, payment outcome) / RECON (A_RECON_3WAY)
  key usage       : abap.char(10) not null;
  // LIFECYCLE: flow + method class (e.g. DACH); RECON: set id (ZCD_HCK_RCSET)
  key scope       : abap.char(10) not null;
  // BAI2 / ISO / PRTRY (RECON: BAI2 only)
  key scheme      : abap.char(5) not null;
  // BAI2 type code / ISO domain / PRTRY code
  key code        : abap.char(35) not null;
  // ISO family; blank otherwise
  key family      : abap.char(35) not null;
  // ISO sub-family; blank otherwise
  key sub_family  : abap.char(35) not null;
  // LIFECYCLE: open list (ORIGINAL, RETURNED ...); RECON: LEG / DEPOSIT / CUTOFF / REDEPOSIT / CHEQUE / OTHER / IGNORE
  role            : abap.char(15);
  // LIFECYCLE: X returns lot / R payment amount / C correction / blank; RECON: blank
  compare_amount  : abap.char(1);
  // RAP configuration apps (design 5): set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}
// Read by ZCL_CD_OPS_PAMAP_DAO when parameter POSTAREA_SOURCE_BTR = T (delivered T: keys of 35 and the role of 15
// characters do not fit TFK033D, CHAR 12). No * in any key. Layout: docs/FICA_Posting_Areas.md. New rows only by
// transport (DV1).

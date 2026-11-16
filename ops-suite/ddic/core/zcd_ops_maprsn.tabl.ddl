@EndUserText.label : 'Ops suite: typed mapping - return / NOC reasons (ZRSN)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zcd_ops_maprsn {
  key mandt       : abap.clnt not null;
  // Mapping version: the reader reads the version of parameter POSTAREA_VERSION_RSN; a rollback sets the
  // previous number (rows of earlier versions stay until they are deleted by transport)
  key version     : abap.numc(4) not null;
  // NACHA return reason R01-R85 / NOC code C01-C07; * = every other reason (FQC0 rule, as posting area ZRSN)
  key reason      : abap.char(4) not null;
  // Payment engine return reason of the returns lot (DFKKRP-RLGRD)
  fica_reason     : abap.char(3);
  // X = notification of change, blank = return
  is_noc          : abap.char(1);
  // RAP configuration apps (design 5): set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}
// Read by ZCL_CD_OPS_PAMAP_DAO when parameter POSTAREA_SOURCE_RSN = T (delivered P: the layout fits the posting area
// ZRSN). Layout and precedence: docs/FICA_Posting_Areas.md. New rows only by transport (DV1).

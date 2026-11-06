@EndUserText.label : 'FMON: PRISM payment requests handled manually'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #DISPLAY
define table zcd_fmon_prq_wa {
  key mandt             : abap.clnt not null;
  key wa_uuid           : sysuuid_x16 not null;
  // PRISM request reference as delivered (ZCD_PAYM_REQ_LOG request key, VERIFY-SE11)
  request_ref           : abap.char(70);
  // Source system of the request (PCLM, ORCI, ...)
  source                : abap.char(10);
  // Handling reference: payment document, ticket, e-mail reference
  reference             : abap.char(70);
  reason                : abap.char(255);
  // H = handled manually (record only - SAP neither re-sends nor re-posts)
  status                : abap.char(1);
  handled_by            : syuname;
  handled_at            : timestampl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
  last_changed_at       : abp_lastchange_tstmpl;
}
// Secondary index REF: history of one request
// @index REF: MANDT, REQUEST_REF

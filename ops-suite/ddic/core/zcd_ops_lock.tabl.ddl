@EndUserText.label : 'Ops suite: run lock argument (E_TABLE)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #L
@AbapCatalog.dataMaintenance : #DISPLAY
define table zcd_ops_lock {
  key mandt     : abap.clnt not null;
  // Payment engine area (EBS / FMON / HCK) and run variant; '*' = whole payment engine area
  key pe_area    : abap.char(4) not null;
  key variant   : abap.char(30) not null;
}
// Never written: the key is only the lock argument of ENQUEUE_E_TABLE / DEQUEUE_E_TABLE
// (ZCL_CD_OPS_LOCK, _SCOPE '1' so the lock survives COMMIT WORK between packages).

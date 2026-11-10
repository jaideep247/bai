@EndUserText.label : 'Ops framework: run lock argument (E_TABLE)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #L
@AbapCatalog.dataMaintenance : #DISPLAY
define table zca_ops_lock {
  key mandt     : abap.clnt not null;
  // Area (parameter area of ZCA_PARAM) and run variant; '*' = the whole area
  key area    : zca_param_area_id not null;
  key variant   : abap.char(30) not null;
}
// Never written: the key is only the lock argument of ENQUEUE_E_TABLE / DEQUEUE_E_TABLE
// (ZCL_CA_OPS_LOCK, _SCOPE '1' so the lock survives COMMIT WORK between packages).

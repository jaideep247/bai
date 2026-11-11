@EndUserText.label : 'Ops framework: SAP job failure evidence - business objects'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #DISPLAY
define table zca_ops_jobbo {
  key mandt     : abap.clnt not null;
  key jobname   : btcjob not null;
  key jobcount  : btcjobcnt not null;
  key object_no : abap.int4 not null;
  // Enricher (ZIF_CA_OPS_JOB_ENRICHER) that linked the object, its type and key (e.g. a business run)
  enricher      : seoclsname;
  object_type   : abap.char(20);
  object_key    : abap.char(70);
  label         : abap.char(60);
  bukrs         : bukrs;
  item_count    : abap.int4;
  // C = confirmed by key, P = probable (name pattern, time window)
  quality       : abap.char(1);
}
// Purged with the job (target JOB_EVIDENCE).

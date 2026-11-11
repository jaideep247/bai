@EndUserText.label : 'Ops framework: SAP job failure evidence - job log'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #DISPLAY
define table zca_ops_jobmsg {
  key mandt     : abap.clnt not null;
  key jobname   : btcjob not null;
  key jobcount  : btcjobcnt not null;
  key line_no   : abap.int4 not null;
  // Error / abort lines of the job log only (JOB_LOG_ERROR_TYPES, at most JOB_MAX_MESSAGES per job):
  // the job log is deleted with the job by the reorganisation
  entered_date  : abap.dats;
  entered_time  : abap.tims;
  msgid         : symsgid;
  msgno         : symsgno;
  msgtype       : symsgty;
  text          : abap.char(255);
}
// Purged with the job (target JOB_EVIDENCE).

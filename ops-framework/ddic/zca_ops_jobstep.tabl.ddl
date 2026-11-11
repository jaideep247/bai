@EndUserText.label : 'Ops framework: SAP job failure evidence - steps'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #DISPLAY
define table zca_ops_jobstep {
  key mandt     : abap.clnt not null;
  key jobname   : btcjob not null;
  key jobcount  : btcjobcnt not null;
  key stepcount : abap.int4 not null;
  // Program and variant of the step (TBTCP; deleted with the job by the reorganisation)
  progname      : abap.char(40);
  variant       : abap.char(14);
  // User the step ran under (authorisations, application log link, scheduler of its children)
  step_user     : syuname;
  // Spool list of the step (the spool itself is not copied; deleted by the spool reorganisation)
  spool_id      : abap.numc(10);
}
// Steps of the jobs of ZCA_OPS_JOB (failed jobs and ancestors); purged with them (target JOB_EVIDENCE).

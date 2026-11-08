@EndUserText.label : 'Payment outcome: parallel snapshot package of a run'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #DISPLAY
define table zcd_pay_outpkg {
  key mandt     : abap.clnt not null;
  // snapshot run (ZCD_OPS_RUN-RUN_ID) that planned the package
  key run_id    : sysuuid_x16 not null;
  // evidence source (ZIF_CD_OPS_PAYOUT_TYPES=>GC_SOURCE) and position of the package in it
  key source    : abap.char(10) not null;
  key pkg_no    : abap.int4 not null;
  // P planned, D done (versions committed), F failed (nothing written), A abandoned (not finished
  // in time: the unit writes nothing any more)
  status        : abap.char(1);
  documents     : abap.int4;
  evaluated     : abap.int4;
  inserted      : abap.int4;
  closed        : abap.int4;
  message       : abap.char(255);
  finished_at   : timestampl;
}
// Written by ZCL_CD_OPS_PAY_SNAPSHOT: the run plans the packages (P) and dispatches them as bgPF
// units (ZCL_CD_OPS_PAY_SNAP_OP); each unit claims its row (SELECT FOR UPDATE, still P), writes its
// versions and sets D in one commit, or F. The run advances each source's watermark only to the end
// of the last contiguous D package. Rows of earlier runs are deleted at the start of the next run
// (run lock held). Never read by the dashboards.

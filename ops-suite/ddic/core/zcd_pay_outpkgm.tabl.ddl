@EndUserText.label : 'Payment outcome: members of a parallel snapshot package'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #DISPLAY
define table zcd_pay_outpkgm {
  key mandt      : abap.clnt not null;
  // package of ZCD_PAY_OUTPKG (run, evidence source, position)
  key run_id     : sysuuid_x16 not null;
  key source     : abap.char(10) not null;
  key pkg_no     : abap.int4 not null;
  // a payment document of the package (FIN and request source blank) ...
  key augbl      : abap.char(12) not null;
  // ... or a payment request of the package (FIN + source, payment document blank)
  key fin_id     : abap.char(35) not null;
  key req_source : abap.char(10) not null;
}
// Members of a parallel package (2026-11-10): written with the package rows when the run plans them,
// read by the package's bgPF unit (ZCL_CD_OPS_PAY_SNAP_OP carries the package key only, never the up
// to 50,000 documents) and deleted with the package rows of earlier runs of the same mode. Why a key
// list and not the watermark range of the package: a range re-read cannot reproduce the package -
// documents already planned for an earlier package or source of the run are left out (each payment is
// judged once per run), RECHECK takes the PAY_STATUS_PENDING rows first (no range) and RECHECK /
// NIGHTLY / NIGHTLYREQ read the worklist itself, which the units of the same wave change. Transient
// processing data, keys only; never read by the dashboards.

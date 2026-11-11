@EndUserText.label : 'Ops framework: findings / owned exceptions'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #DISPLAY
define table zca_ops_finding {
  key mandt     : abap.clnt not null;
  key run_id    : sysuuid_x16 not null;
  key finding_no : abap.int4 not null;
  area        : zca_param_area_id;
  object_type   : abap.char(10);
  object_key    : abap.char(70);
  group1        : abap.char(35);
  group2        : abap.char(35);
  rule_id       : abap.char(10);
  check_code    : abap.char(30);
  severity      : abap.char(1);
  action        : abap.char(10);
  amount        : abap.dec(23,2);
  currency      : abap.char(5);
  reference     : abap.char(35);
  message       : abap.char(255);
  details       : abap.string(0);
  // Exception lifecycle: O = open, I = information, A = assigned, R = resolved, W = waived, S = superseded
  disposition   : abap.char(1);
  owner         : syuname;
  due_date      : abap.dats;
  resolved_by   : syuname;
  resolved_at   : timestampl;
  resolution    : abap.char(255);
  // Carry-forward: first run that raised this exception, how often it was raised,
  // and the later run whose row replaced this one (disposition S)
  first_seen_at : timestampl;
  occurrences   : abap.int4;
  superseded_by : sysuuid_x16;
  // Waiver valid until (disposition W); a re-run keeps the waiver while valid
  waiver_until  : abap.dats;
  // Waiver request (exceptions app, four-eyes): requester, time and reason;
  // approved by a different user (RESOLVED_BY), then disposition W
  waiver_req_by : syuname;
  waiver_req_at : timestampl;
  waiver_reason : abap.char(255);
  created_by    : syuname;
  created_at    : timestampl;
  // Change stamp (UTC, 2026-11-10): set by every write - the store (insert, supersede, resolve), the
  // exception repository and the exceptions app (ETag of ZR_CA_OpsException); a batch write is guarded
  // by the stamp it read, so a user's change in between is never overwritten
  last_changed_at : timestampl;
  // Error class of a finding raised at a catch boundary (TRANSIENT, DATA, CONFIG, CODE; 2026-11-10)
  error_class   : abap.char(10);
  // Classification of an open exception by operations (exceptions app, action classifyException;
  // values of parameter EXC_REASON_CODES, e.g. TIMING, INVESTIGATING; 2026-11-10) - carried forward
  reason_code   : abap.char(12);
  // Company code of the finding (2026-11-10, company-code isolation): blank = not company-specific
  // (an area-level finding, visible with the area authorisation); filled by the producer where it knows
  // the company code at finding time. Read authorisation (DCLs) and the actions of the exceptions app check
  // ZCA_OPS with BUKRS for a filled value; part of the identity of an exception (carry-forward)
  bukrs         : bukrs;
  // Planned downtime (2026-11-11): the approved window (ZCA_OPS_DTWIN) that covered the finding when it was
  // recorded - the finding is recorded as usual, the alert router suppresses its alert (ZCA_OPS_ALLOG status D).
  // Set by the store at write time: the scope patterns (PCRE) cannot be evaluated in CDS. Blank = no window
  downtime_id   : sysuuid_x16;
  // Alert correlation (2026-11-11, ZCA_OPS_CORR): the group of exceptions of one correlation key and window -
  // a correlation ID, not a pointer to the parent row, because the carry-forward supersedes the parent's row
  // (run ID and finding number) at every run that raises it again; the ID is inherited like owner and reason
  // code. CORR_ROLE P = parent (the first exception of the key in the window, alerted with the number of its
  // children), C = child (not alerted on its own). CORR_KEY = SHA-1 of area, rule, company code and key value
  // (finds the open parent of a new exception). Blank = not correlated
  corr_id       : sysuuid_x16;
  corr_role     : abap.char(1);
  corr_key      : abap.char(40);
  // Explainable, versioned results (2026-11-11, docs/EXPLAINABLE_RESULTS.md): CFG_VERSION = the configuration
  // version that produced the finding - SHA-1 of the effective configuration rows of its check (registry row,
  // aggregate rows, bucket rules, the parameter values the check reads; ZCL_CA_OPS_CFG_VERSION), set by the
  // runner; CFG_RULE = the configuration row inside the check that produced or explained the finding (aggregate
  // ID, bucket rule ID). The check ID is GROUP2, the rule RULE_ID. Blank = not known (a producer outside the
  // runner). Not inherited by the carry-forward: each row keeps the version of its own run, so a later run under
  // another configuration is visible (control review: sign-off reopened, reason CONFIG)
  cfg_version   : abap.char(40);
  cfg_rule      : abap.char(20);
  // Pilot metrics (2026-11-11, docs/PILOT_PACK.md): the business date the finding is about and, where the
  // producer knows it, the time of the business event (UTC) - time to detect = FIRST_SEEN_AT - EVENT_AT
  // (else the business date); blank = not known
  bus_date      : abap.dats;
  event_at      : timestampl;
}
// Secondary indexes OPN: exception queue / aging; OBJ: drill-down, idempotent re-validation,
// carry-forward and reconcile. Performance fix 5: OBJ without OBJECT_TYPE - reconcile( ) and
// the exception repository know only the object key, so a leading OBJECT_TYPE left AREA alone usable
// @index OPN: MANDT, AREA, DISPOSITION, DUE_DATE
// @index OBJ: MANDT, AREA, OBJECT_KEY
// COR (2026-11-11): the open parent of a correlation key (store) and the children of a group (router, apps)
// @index COR: MANDT, CORR_KEY
// CRI (2026-11-11): the exceptions of a correlation group (exceptions app facet, child counts)
// @index CRI: MANDT, CORR_ID

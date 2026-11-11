@EndUserText.label : 'Ops framework: break analysis groups'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #DISPLAY
define table zca_ops_brkgrp {
  key mandt     : abap.clnt not null;
  key snap_id   : sysuuid_x16 not null;
  key group_no  : abap.int4 not null;
  // Group = the journal lines of the account with one assignment (ZUONR) in one currency that do not net to zero at
  // the key date; amounts are never summed across currencies
  assignment    : abap.char(18);
  currency      : abap.char(5);
  // Net of the lines up to the key date (transaction currency) and the number of lines
  amount        : abap.dec(23,2);
  line_count    : abap.int4;
  first_date    : abap.dats;
  last_date     : abap.dats;
  // Days from the oldest line to the key date
  age_days      : abap.int4;
  // Lines after the key date (forward window): their net, and X when they bring the group to zero
  later_amount  : abap.dec(23,2);
  clears_later  : abap_boolean;
  later_date    : abap.dats;
  // Bucket of the group = the bucket of the first rule (lowest sequence) that explains one of its lines; OTHER when
  // no rule explains a line
  bucket        : abap.char(20);
  explained     : abap_boolean;
  rule_id       : abap.char(20);
  reason        : abap.char(255);
  // Reconciliation key of the oldest line (reference key of its journal entry, e.g. the FI-CA reconciliation key)
  recon_key     : abap.char(20);
}

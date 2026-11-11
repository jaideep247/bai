@EndUserText.label : 'Ops framework: break analysis items'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #DISPLAY
define table zca_ops_brkitm {
  key mandt     : abap.clnt not null;
  key snap_id   : sysuuid_x16 not null;
  key group_no  : abap.int4 not null;
  key item_no   : abap.int4 not null;
  // Journal entry line (drill-down to I_JournalEntryItem by its key)
  ledger        : abap.char(2);
  bukrs         : bukrs;
  gjahr         : gjahr;
  belnr         : belnr_d;
  docln         : abap.char(6);
  posting_date  : abap.dats;
  document_date : abap.dats;
  doc_type      : abap.char(2);
  debit_credit  : abap.char(1);
  amount        : abap.dec(23,2);
  currency      : abap.char(5);
  // Reference of the journal entry: type (AWTYP) and key (AWREF + AWORG - for a FI-CA G/L transfer the
  // reconciliation key)
  ref_type      : abap.char(5);
  recon_key     : abap.char(20);
  // X = posted after the key date (context of the group, not an open line at the key date)
  later         : abap_boolean;
  // Bucket and rule that explain the line (blank on a later line; OTHER = no rule)
  bucket        : abap.char(20);
  rule_id       : abap.char(20);
  // Linked object the matching rule read (link registry), its key (sensitive values masked) and the value compared
  link_object   : abap.char(30);
  link_key      : abap.char(70);
  link_value    : abap.char(40);
}

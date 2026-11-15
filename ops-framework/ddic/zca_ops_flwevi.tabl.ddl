@EndUserText.label : 'Ops framework: account flow evaluation items'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #DISPLAY
define table zca_ops_flwevi {
  key mandt     : abap.clnt not null;
  key eval_id   : sysuuid_x16 not null;
  key item_no   : abap.int4 not null;
  flow_acct     : abap.char(20);
  role          : abap.char(15);
  bukrs         : bukrs;
  currency      : abap.char(5);
  // TRANSIT, CLARIFY, OPEN, BANK (EVAL_CATEGORY of the account)
  category      : abap.char(10);
  // Signed as the journal (debit +): the part of the closing position the source accounts for
  amount        : abap.dec(23,2);
  item_count    : abap.int4;
  // E evaluated, N not evaluated (REASON says why - shown grey, never as zero)
  status        : abap.char(1);
  source_class  : abap.char(30);
  reason        : abap.char(120);
}

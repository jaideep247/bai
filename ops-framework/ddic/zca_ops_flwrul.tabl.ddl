@EndUserText.label : 'Ops framework: account flow stage rules'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table zca_ops_flwrul {
  key mandt     : abap.clnt not null;
  key area      : zca_param_area_id not null;
  key flow_id   : abap.char(10) not null;
  // Order: the first rule (lowest sequence) whose filled criteria all hold gives a line its stage - first match
  // wins, unique by the key; a line no rule matches is shown in the row OTHER, never hidden
  key rule_seq  : abap.numc(4) not null;
  rule_id       : abap.char(20);
  stage_id      : abap.char(20);
  // G = a journal line (criteria REF_TYPE, DOC_TYPE, DEBIT_CREDIT); F = a line of an FI-CA document (DOC_TYPE,
  // ORIGIN, MAIN_TRANS, SUB_TRANS, DEBIT_CREDIT); a blank criterion matches any value
  line_source   : abap.char(1);
  // Journal: reference transaction (AWTYP, e.g. FKKSU = G/L transfer of FI-CA)
  ref_type      : abap.char(5);
  // Journal: document type (BLART); FI-CA: document type of the FI-CA document
  doc_type      : abap.char(2);
  // FI-CA: origin key of the document; main and sub-transaction of a business partner item
  origin        : abap.char(2);
  main_trans    : abap.char(4);
  sub_trans     : abap.char(4);
  // S = debit, H = credit (blank = both)
  debit_credit  : abap.char(1);
  description   : abap.char(60);
  active        : abap_boolean;
  // RAP configuration app: set by the framework, ignored by engines
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;
}

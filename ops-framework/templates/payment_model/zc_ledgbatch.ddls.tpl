// Artifact: zc_{{p}}_ledgbatch.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Ledger model of the {{CONSUMER}} - batch key level (entity SubledgerBatch of {{SERVICE}}): list with a
//          mandatory posting date and the object page of one batch key per account and currency with its journal
//          lines and subledger items. Read access: DCL ZC_{{P}}_PAYM.
// Modification log: {{SINCE}} | Generated from the product template (ledger model).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Ledger model - batch key level'
@Metadata.allowExtensions: true
define root view entity ZC_{{P}}_LedgBatch
  provider contract transactional_query
  as projection on ZR_{{P}}_LedgBatch
{
  key BatchKey,
  key CompanyCode,
  key GlAccount,
  key Currency,
      _Journal : redirected to ZC_{{P}}_LedgJrnl,
      _Items   : redirected to ZC_{{P}}_LedgItem,
      OpsArea,
      GlReferenceKey,
      PostingDate,
      BatchStatus,
      @Semantics.amount.currencyCode: 'Currency'
      SubledgerAmount,
      SubledgerLineCount,
      @Semantics.amount.currencyCode: 'Currency'
      GlAmount,
      GlLineCount,
      GlDocumentCount,
      ReversedDocumentCount,
      GlFiscalYear,
      GlDocument,
      Difference,
      TransferStatus,
      IsTransferred,
      StatusCriticality,
      @Aggregation.default: #SUM
      KeyCount
}

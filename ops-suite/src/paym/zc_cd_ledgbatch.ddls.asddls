// Artifact: zc_cd_ledgbatch.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Ledger model of the ops suite - batch key level (entity SubledgerBatch of ZUI_CD_PAYM): list with a
//          mandatory posting date and the object page of one batch key per account and currency with its journal
//          lines and subledger items. Read access: DCL ZC_CD_PAYM.
// Modification log: 2026-11-11 | Generated from the product template (ledger model).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Ledger model - batch key level'
@Metadata.allowExtensions: true
define root view entity ZC_CD_LedgBatch
  provider contract transactional_query
  as projection on ZR_CD_LedgBatch
{
  key BatchKey,
  key CompanyCode,
  key GlAccount,
  key Currency,
      _Journal : redirected to ZC_CD_LedgJrnl,
      _Items   : redirected to ZC_CD_LedgItem,
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

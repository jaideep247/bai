// Artifact: zc_cd_ledgitem.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Ledger model of the ops suite - subledger item (entity SubledgerItem of ZUI_CD_PAYM): items table of the
//          payment ledger and batch key pages, object page of one item with the links up to its payment and batch key.
//          Read access: DCL ZC_CD_PAYM.
// Modification log: 2026-11-11 | Generated from the product template (ledger model).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Ledger model - subledger item'
@Metadata.allowExtensions: true
define root view entity ZC_CD_LedgItem
  provider contract transactional_query
  as projection on ZR_CD_LedgItem
{
  key PaymentDocument,
  key SubledgerDocument,
  key SubledgerItem,
      _Payment : redirected to ZC_CD_Payment,
      _Batch   : redirected to ZC_CD_LedgBatch,
      OpsArea,
      CompanyCode,
      BatchKey,
      GlAccount,
      Currency,
      @Semantics.amount.currencyCode: 'Currency'
      Amount,
      PostingDate,
      @ObjectModel.text.element: [ 'MainTransactionText' ]
      MainTransaction,
      @Semantics.text: true
      MainTransactionText,
      @ObjectModel.text.element: [ 'SubTransactionText' ]
      SubTransaction,
      @Semantics.text: true
      SubTransactionText,
      ContractAccount,
      BusinessPartnerMasked,
      ClearingDocument,
      ClearingDate,
      ClearingReason,
      RequestReference,
      @Aggregation.default: #SUM
      ItemCount
}

// Artifact: zc_{{p}}_ledgitem.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Ledger model of the {{CONSUMER}} - subledger item (entity SubledgerItem of {{SERVICE}}): items table of the
//          payment ledger and batch key pages, object page of one item with the links up to its payment and batch key.
//          Read access: DCL ZC_{{P}}_PAYM.
// Modification log: {{SINCE}} | Generated from the product template (ledger model).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Ledger model - subledger item'
@Metadata.allowExtensions: true
define root view entity ZC_{{P}}_LedgItem
  provider contract transactional_query
  as projection on ZR_{{P}}_LedgItem
{
  key PaymentDocument,
  key SubledgerDocument,
  key SubledgerItem,
      _Payment : redirected to ZC_{{P}}_Payment,
      _Batch   : redirected to ZC_{{P}}_LedgBatch,
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

// Artifact: zc_{{p}}_paymledger.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Ledger model of the {{CONSUMER}} - payment ledger (entity PaymentLedger of {{SERVICE}}): the "Ledger" facet
//          of the payment object page - share of the batch summary, G/L total, transfer status, journal lines and items.
//          Read access: DCL ZC_{{P}}_PAYM.
// Modification log: {{SINCE}} | Generated from the product template (ledger model).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Ledger model - payment ledger'
@Metadata.allowExtensions: true
define root view entity ZC_{{P}}_PaymLedger
  provider contract transactional_query
  as projection on ZR_{{P}}_PaymLedger
{
  key PaymentDocument,
  key BatchKey,
  key CompanyCode,
  key GlAccount,
  key Currency,
      _Journal : redirected to ZC_{{P}}_LedgJrnl,
      _Items   : redirected to ZC_{{P}}_LedgItem,
      OpsArea,
      @Semantics.amount.currencyCode: 'Currency'
      PaymentAmount,
      ItemCount,
      GlReferenceKey,
      BatchPostingDate,
      BatchStatus,
      @Semantics.amount.currencyCode: 'Currency'
      BatchAmount,
      @Semantics.amount.currencyCode: 'Currency'
      GlAmount,
      GlDocumentCount,
      GlFiscalYear,
      GlDocument,
      SharePercent,
      ProRataGlAmount,
      BatchDifference,
      TransferStatus,
      StatusCriticality
}

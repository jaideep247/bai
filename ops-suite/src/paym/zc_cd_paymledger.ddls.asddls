// Artifact: zc_cd_paymledger.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Ledger model of the ops suite - payment ledger (entity PaymentLedger of ZUI_CD_PAYM): the "Ledger" facet
//          of the payment object page - share of the batch summary, G/L total, transfer status, journal lines and items.
//          Read access: DCL ZC_CD_PAYM.
// Modification log: 2026-11-11 | Generated from the product template (ledger model).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Ledger model - payment ledger'
@Metadata.allowExtensions: true
define root view entity ZC_CD_PaymLedger
  provider contract transactional_query
  as projection on ZR_CD_PaymLedger
{
  key PaymentDocument,
  key BatchKey,
  key CompanyCode,
  key GlAccount,
  key Currency,
      _Journal : redirected to ZC_CD_LedgJrnl,
      _Items   : redirected to ZC_CD_LedgItem,
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

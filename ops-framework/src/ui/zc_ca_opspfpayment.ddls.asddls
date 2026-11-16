// Artifact: zc_ca_opspfpayment.ddls.asddls
// Purpose: Payment file lifecycle - consumption view of the affected payments of a file (object page facet of ZC_CA_OpsPayFile; payee masked). Read access: DCL ZC_CA_OPSPFPAYMENT.
// Modification log: 2026-11-15 | Initial version (build K: payment file lifecycle).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Payments of a payment file'
@Metadata.allowExtensions: true
define root view entity ZC_CA_OpsPfPayment
  provider contract transactional_query
  as projection on ZR_CA_OpsPfPayment
{
  key Area,
  key FileId,
  key PaymentKey,
      CompanyCode,
      Currency,
      Amount,
      AmountKnown,
      PayeeMasked,
      PaymentDocument,
      PaymentMethod,
      BatchId,
      AckOutcome,
      AckAt,
      OtherFileId,
      PossibleDuplicate
}

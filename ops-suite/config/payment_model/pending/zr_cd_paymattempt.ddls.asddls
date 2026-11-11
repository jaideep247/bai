// Artifact: zr_cd_paymattempt.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Payment model of the ops suite - every attempt of a payment request (adapter ZI_CD_PaymAttempt):
//          attempt number, processing status, received at and whether it is the accepted attempt (the consumer's
//          rule in the mapping spec - e.g. the successful row, never simply the highest attempt number). Read-only.
// Modification log: 2026-11-11 | Generated from the product template (payment model).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment model - request attempt'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
define root view entity ZR_CD_PaymAttempt
  as select from ZI_CD_PaymAttempt as Att
{
  key Att.RequestReference,
  key Att.AttemptNumber,
      Att.CompanyCode,
      cast( 'CD_OPS' as abap.char( 16 ) )                 as OpsArea,
      Att.ProcessingStatus,
      Att.ReceivedAt,
      Att.IsAccepted
}

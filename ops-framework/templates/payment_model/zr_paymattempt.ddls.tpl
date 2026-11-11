// Artifact: zr_{{p}}_paymattempt.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Payment model of the {{CONSUMER}} - every attempt of a payment request (adapter ZI_{{P}}_PaymAttempt):
//          attempt number, processing status, received at and whether it is the accepted attempt (the consumer's
//          rule in the mapping spec - e.g. the successful row, never simply the highest attempt number). Read-only.
// Modification log: {{SINCE}} | Generated from the product template (payment model).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment model - request attempt'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
define root view entity ZR_{{P}}_PaymAttempt
  as select from ZI_{{P}}_PaymAttempt as Att
{
  key Att.RequestReference,
  key Att.AttemptNumber,
      Att.CompanyCode,
      cast( '{{AREA}}' as abap.char( 16 ) )                 as OpsArea,
      Att.ProcessingStatus,
      Att.ReceivedAt,
      Att.IsAccepted
}

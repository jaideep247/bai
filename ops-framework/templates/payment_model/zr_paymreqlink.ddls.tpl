// Artifact: zr_{{p}}_paymreqlink.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Payment model of the {{CONSUMER}} - link between a payment and a request (n:m: a payment can settle
//          several requests, a request can be paid by several payments): adapter ZI_{{P}}_PaymReqLink. Navigation
//          payment -> requests (from ZR_{{P}}_Payment) and request -> payments (_Payments). Read by key through the
//          navigations; the adapter's access path is recorded in the consumer's performance review. Read-only.
// Modification log: {{SINCE}} | Generated from the product template (payment model).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment model - payment to request'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
define root view entity ZR_{{P}}_PaymReqLink
  as select from ZI_{{P}}_PaymReqLink as Link
  association [0..*] to ZR_{{P}}_Payment     as _Payments on $projection.PaymentDocument = _Payments.PaymentDocument
#if REQUEST
  association [0..1] to ZR_{{P}}_PaymRequest as _Request  on $projection.RequestReference = _Request.RequestReference
#endif
{
  key Link.PaymentDocument,
  key Link.RequestReference,
      _Payments,
#if REQUEST
      _Request,
#endif
      Link.CompanyCode,
      cast( '{{AREA}}' as abap.char( 16 ) )                 as OpsArea
}

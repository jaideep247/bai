// Artifact: zr_cd_paymreqlink.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Payment model of the ops suite - link between a payment and a request (n:m: a payment can settle
//          several requests, a request can be paid by several payments): adapter ZI_CD_PaymReqLink. Navigation
//          payment -> requests (from ZR_CD_Payment) and request -> payments (_Payments). Read by key through the
//          navigations; the adapter's access path is recorded in the consumer's performance review. Read-only.
// Modification log: 2026-11-11 | Generated from the product template (payment model).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment model - payment to request'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
define root view entity ZR_CD_PaymReqLink
  as select from ZI_CD_PaymReqLink as Link
  association [0..*] to ZR_CD_Payment     as _Payments on $projection.PaymentDocument = _Payments.PaymentDocument
{
  key Link.PaymentDocument,
  key Link.RequestReference,
      _Payments,
      Link.CompanyCode,
      cast( 'CD_OPS' as abap.char( 16 ) )                 as OpsArea
}

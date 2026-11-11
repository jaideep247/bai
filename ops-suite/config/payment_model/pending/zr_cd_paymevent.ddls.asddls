// Artifact: zr_cd_paymevent.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Payment model of the ops suite - timeline of a payment request (adapter ZI_CD_PaymEvent): one row per
//          hop - FEEDER (sent by the feeder system), MIDDLEWARE (file / message of the middleware), REQUEST (received
//          by SAP), PAYMENT (paid in a payment run), STATUS_BACK (status sent back to the feeder) - in time order.
// Modification log: 2026-11-11 | Generated from the product template (payment model).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment model - request timeline'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
define root view entity ZR_CD_PaymEvent
  as select from ZI_CD_PaymEvent as Evt
{
  key Evt.RequestReference,
  key Evt.EventSequence,
      Evt.CompanyCode,
      cast( 'CD_OPS' as abap.char( 16 ) )                 as OpsArea,
      Evt.EventAt,
      Evt.Hop,
      Evt.EventStatus,
      Evt.EventReference
}

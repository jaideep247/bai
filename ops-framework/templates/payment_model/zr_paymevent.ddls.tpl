// Artifact: zr_{{p}}_paymevent.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Payment model of the {{CONSUMER}} - timeline of a payment request (adapter ZI_{{P}}_PaymEvent): one row per
//          hop - FEEDER (sent by the feeder system), MIDDLEWARE (file / message of the middleware), REQUEST (received
//          by SAP), PAYMENT (paid in a payment run), STATUS_BACK (status sent back to the feeder) - in time order.
// Modification log: {{SINCE}} | Generated from the product template (payment model).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment model - request timeline'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
define root view entity ZR_{{P}}_PaymEvent
  as select from ZI_{{P}}_PaymEvent as Evt
{
  key Evt.RequestReference,
  key Evt.EventSequence,
      Evt.CompanyCode,
      cast( '{{AREA}}' as abap.char( 16 ) )                 as OpsArea,
      Evt.EventAt,
      Evt.Hop,
      Evt.EventStatus,
      Evt.EventReference
}

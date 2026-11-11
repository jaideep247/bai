// Artifact: zc_cd_paymevent.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Payment model of the ops suite - request timeline (entity PaymentRequestEvent of ZUI_CD_PAYM).
//          Read access: DCL ZC_CD_PAYM.
// Modification log: 2026-11-11 | Generated from the product template (payment model).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Payment model - request timeline'
@Metadata.allowExtensions: true
@UI.presentationVariant: [ { sortOrder: [ { by: 'EventAt', direction: #ASC } ] } ]
define root view entity ZC_CD_PaymEvent
  provider contract transactional_query
  as projection on ZR_CD_PaymEvent
{
      @EndUserText.label: 'Request reference'
  key RequestReference,
      @EndUserText.label: 'Step'
  key EventSequence,
      @EndUserText.label: 'Company code'
      CompanyCode,
      @UI.hidden: true
      OpsArea,
      @EndUserText.label: 'At'
      @UI.lineItem: [ { position: 10 } ]
      EventAt,
      @EndUserText.label: 'Hop'
      @UI.lineItem: [ { position: 20 } ]
      Hop,
      @EndUserText.label: 'Status'
      @UI.lineItem: [ { position: 30 } ]
      EventStatus,
      @EndUserText.label: 'Reference'
      @UI.lineItem: [ { position: 40 } ]
      EventReference
}

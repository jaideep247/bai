// Artifact: zc_cd_paymchange.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Document-change model of the ops suite - payment changes (entity PaymentChange of ZUI_CD_PAYM): the
//          "Changes" facet of the payment object page (and of a bank line). Read access: DCL ZC_CD_PAYM.
// Modification log: 2026-11-11 | Generated from the product template (document-change model).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Document-change model - payment changes'
@Metadata.allowExtensions: true
define root view entity ZC_CD_PaymChange
  provider contract transactional_query
  as projection on ZR_CD_PaymChange
{
  key PaymentDocument,
  key EventType,
  key EventDocument,
      _NewPayment : redirected to ZC_CD_Payment,
      OpsArea,
      @Semantics.text: true
      EventTypeText,
      CompanyCode,
      OriginalDocument,
      NewDocument,
      ReversalDocument,
      EventDate,
      EventTime,
      EventUser,
      Reason,
      EventSource,
      EventCriticality
}

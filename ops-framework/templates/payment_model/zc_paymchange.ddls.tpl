// Artifact: zc_{{p}}_paymchange.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Document-change model of the {{CONSUMER}} - payment changes (entity PaymentChange of {{SERVICE}}): the
//          "Changes" facet of the payment object page (and of a bank line). Read access: DCL ZC_{{P}}_PAYM.
// Modification log: {{SINCE}} | Generated from the product template (document-change model).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Document-change model - payment changes'
@Metadata.allowExtensions: true
define root view entity ZC_{{P}}_PaymChange
  provider contract transactional_query
  as projection on ZR_{{P}}_PaymChange
{
  key PaymentDocument,
  key EventType,
  key EventDocument,
      _NewPayment : redirected to ZC_{{P}}_Payment,
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

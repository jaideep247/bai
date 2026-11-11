// Artifact: zc_cd_reqchange.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Document-change model of the ops suite - request changes (entity RequestChange of ZUI_CD_PAYM): the
//          "Changes" facet of the request object page. Read access: DCL ZC_CD_PAYM.
// Modification log: 2026-11-11 | Generated from the product template (document-change model).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Document-change model - request changes'
@Metadata.allowExtensions: true
define root view entity ZC_CD_ReqChange
  provider contract transactional_query
  as projection on ZR_CD_ReqChange
{
  @EndUserText.label: 'Request'
  key RequestReference,
  @EndUserText.label: 'Payment'
  @UI.lineItem: [ { position: 10 } ]
  key PaymentDocument,
  @EndUserText.label: 'Change'
  @UI.lineItem: [ { position: 20, criticality: 'EventCriticality' } ]
  key EventType,
  @EndUserText.label: 'Document of the change'
  key EventDocument,
      @UI.hidden: true
      OpsArea,
      @EndUserText.label: 'Change'
      EventTypeText,
      CompanyCode,
      @EndUserText.label: 'Original (old) document'
      @UI.lineItem: [ { position: 30 } ]
      OriginalDocument,
      @EndUserText.label: 'New document'
      @UI.lineItem: [ { position: 40 } ]
      NewDocument,
      @EndUserText.label: 'Reversal document'
      ReversalDocument,
      @EndUserText.label: 'Date'
      @UI.lineItem: [ { position: 50 } ]
      EventDate,
      EventTime,
      @EndUserText.label: 'User'
      EventUser,
      Reason,
      @EndUserText.label: 'Source'
      @UI.lineItem: [ { position: 60 } ]
      EventSource,
      @UI.hidden: true
      EventCriticality
}

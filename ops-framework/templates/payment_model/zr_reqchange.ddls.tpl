// Artifact: zr_{{p}}_reqchange.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Document-change model of the {{CONSUMER}} - the "Changes" timeline of a request (entity RequestChange):
//          the change events of every payment that settled the request (payment - request link, n:m). Read by request
//          reference (navigation from the request page). Read-only.
// Modification log: {{SINCE}} | Generated from the product template (document-change model).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Document-change model - request changes'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define root view entity ZR_{{P}}_ReqChange
  as select from ZI_{{P}}_PaymReqLink as Link
    inner join   ZR_{{P}}_PaymChange  as Chg on Chg.PaymentDocument = Link.PaymentDocument
{
  key Link.RequestReference,
  key Chg.PaymentDocument,
  key Chg.EventType,
  key Chg.EventDocument,
      Chg.OpsArea,
      Chg.EventTypeText,
      Chg.CompanyCode,
      Chg.OriginalDocument,
      Chg.NewDocument,
      Chg.ReversalDocument,
      Chg.EventDate,
      Chg.EventTime,
      Chg.EventUser,
      Chg.Reason,
      Chg.EventSource,
      Chg.EventCriticality
}

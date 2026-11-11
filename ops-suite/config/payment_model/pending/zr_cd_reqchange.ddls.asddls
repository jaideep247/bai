// Artifact: zr_cd_reqchange.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Document-change model of the ops suite - the "Changes" timeline of a request (entity RequestChange):
//          the change events of every payment that settled the request (payment - request link, n:m). Read by request
//          reference (navigation from the request page). Read-only.
// Modification log: 2026-11-11 | Generated from the product template (document-change model).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Document-change model - request changes'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define root view entity ZR_CD_ReqChange
  as select from ZI_CD_PaymReqLink as Link
    inner join   ZR_CD_PaymChange  as Chg on Chg.PaymentDocument = Link.PaymentDocument
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

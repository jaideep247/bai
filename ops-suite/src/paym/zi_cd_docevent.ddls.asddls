// Artifact: zi_cd_docevent.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Payment model of the ops suite - ADAPTER of the document-change event: the contract fields of the product
//          (docs/ADDING_A_CUSTOMER_PAYMENT_MODEL.md) mapped to this landscape by the mapping spec config/payment_model/mapping.json.
//          Reversals (DFKKKO-STBEL) and stopped cheques (DPAYH status STOPPED) of the payments of the payment model window
//          (ZI_CD_DocEvtU). Clearing reset / re-clearing / reissue link need the clearing-reset history (TRACE_SRC_HISTORY,
//          DFKKRAPT candidate, V100) - not mapped until confirmed; returns (DFKKRP) are not change events.
// Modification log: 2026-11-11 | Generated from the mapping spec (payment model).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment model - adapter document-change event'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
define view entity ZI_CD_DocEvent
  as select from ZI_CD_DocEvtU as Evt
{
  key Evt.PaymentDocument as PaymentDocument,
  key Evt.EventType as EventType,
  key Evt.EventDocument as EventDocument,
      Evt.CompanyCode as CompanyCode,
      Evt.OriginalDocument as OriginalDocument,
      Evt.NewDocument as NewDocument,
      Evt.ReversalDocument as ReversalDocument,
      Evt.EventDate as EventDate,
      Evt.EventTime as EventTime,
      Evt.EventUser as EventUser,
      Evt.Reason as Reason,
      Evt.EventSource as EventSource
}

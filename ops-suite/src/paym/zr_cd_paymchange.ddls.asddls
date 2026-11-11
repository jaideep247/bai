// Artifact: zr_cd_paymchange.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Document-change model of the ops suite - the "Changes" timeline of a payment (entity PaymentChange): one
//          row per event - type with its text (dimension DOC_EVENT of the dimension texts), date and time, source
//          (subledger, payment run, G/L), user, reason, and the documents explicitly linked: ORIGINAL (old clearing /
//          reversed document) -> NEW (re-clearing / reissue) and the REVERSAL document. A bank line keeps referencing the
//          OLD clearing document, so the timeline is where support sees why it no longer clears. The new document opens
//          as a payment of its own (_NewPayment). User IDs are shown here as the exceptions app shows owners (object
//          page of one payment, read access as the payment); never on the volume cards. Read-only.
// Modification log: 2026-11-11 | Generated from the product template (document-change model).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Document-change model - payment changes'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define root view entity ZR_CD_PaymChange
  as select from    ZI_CD_DocEvtAll as Evt
    left outer join ZI_CA_PaymDimText  as EvtT on  EvtT.Language  = $session.system_language
                                               and EvtT.Dimension = 'DOC_EVENT'
                                               and EvtT.DimValue  = Evt.EventType
  association [0..*] to ZR_CD_Payment as _NewPayment on $projection.NewDocument = _NewPayment.PaymentDocument
{
  key Evt.PaymentDocument,
  key Evt.EventType,
  key Evt.EventDocument,
      _NewPayment,
      cast( 'CD_OPS' as abap.char( 16 ) )                 as OpsArea,
      EvtT.DimText                                          as EventTypeText,
      Evt.CompanyCode,
      Evt.OriginalDocument,
      Evt.NewDocument,
      Evt.ReversalDocument,
      Evt.EventDate,
      Evt.EventTime,
      Evt.EventUser,
      Evt.Reason,
      Evt.EventSource,
      cast( case when Evt.EventType = 'CLEARING_RESET' and Evt.NewDocument = '' then 1
                 when Evt.EventType = 'RECLEARING' or Evt.EventType = 'REISSUE' then 3
                 else 2 end as abap.int1 )                  as EventCriticality
}

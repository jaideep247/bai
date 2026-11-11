// Artifact: zi_cd_docevtall.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Document-change model of the ops suite - every document-change event of a payment: the consumer's events
//          (adapter ZI_CD_DocEvent: REVERSAL, CLEARING_RESET, RECLEARING, VOID, REISSUE with original, new and
//          reversal document, user, time, reason) and, with the ledger model, the standard G/L reversal (GL_REVERSAL) of
//          a G/L document of the payment's batch keys (BKPF-STBLG / STJAH of the reversed document; the reversal
//          document's entry date / time, user and reversal reason). Read by payment document. Read-only.
// Modification log: 2026-11-11 | Generated from the product template (document-change model).
// VERIFY-SE11: BKPF USNAM, STGRD, STJAH, CPUDT, CPUTM. VERIFY-ADT: UNION ALL of an adapter with typed literals (7.58).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Document-change model - events'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define view entity ZI_CD_DocEvtAll
  as select from ZI_CD_DocEvent as Evt
{
  key Evt.PaymentDocument,
  key Evt.EventType,
  key Evt.EventDocument,
      Evt.CompanyCode,
      Evt.OriginalDocument,
      Evt.NewDocument,
      Evt.ReversalDocument,
      Evt.EventDate,
      Evt.EventTime,
      Evt.EventUser,
      Evt.Reason,
      Evt.EventSource
}
union all select from ZI_CD_LedgPayBat as Pay
  inner join          ZI_CD_LedgGlDoc  as Doc on  Doc.BatchKey    = Pay.BatchKey
                                                 and Doc.CompanyCode = Pay.CompanyCode
  inner join          bkpf                as Rev on  Rev.bukrs = Doc.CompanyCode
                                                 and Rev.belnr = Doc.ReversalDocument
                                                 and Rev.gjahr = Doc.ReversalYear
{
  key Pay.PaymentDocument,
  key cast( 'GL_REVERSAL' as abap.char( 16 ) )              as EventType,
  key cast( Rev.belnr as abap.char( 20 ) )                  as EventDocument,
      Doc.CompanyCode,
      cast( Doc.GlDocument as abap.char( 20 ) )             as OriginalDocument,
      cast( '' as abap.char( 20 ) )                         as NewDocument,
      cast( Rev.belnr as abap.char( 20 ) )                  as ReversalDocument,
      Rev.cpudt                                             as EventDate,
      Rev.cputm                                             as EventTime,
      Rev.usnam                                             as EventUser,
      Rev.stgrd                                             as Reason,
      cast( 'GL' as abap.char( 10 ) )                       as EventSource
}
where
  Doc.IsReversed = 'X'

// Artifact: zi_{{p}}_docevtall.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Document-change model of the {{CONSUMER}} - every document-change event of a payment: the consumer's events
//          (adapter ZI_{{P}}_DocEvent: REVERSAL, CLEARING_RESET, RECLEARING, VOID, REISSUE with original, new and
//          reversal document, user, time, reason) and, with the ledger model, the standard G/L reversal (GL_REVERSAL) of
//          a G/L document of the payment's batch keys (reverse document / its fiscal year on the reversed
//          document's header; the reversal document's entry date / time, user and reversal reason from the released
//          view I_JournalEntry). Read by payment document. Read-only.
// Modification log: {{SINCE}} | Generated from the product template (document-change model).
//                   2026-11-11 | Reversal document header from the released view I_JournalEntry (was the document
//                              | header table); element names unchanged.
// VERIFY-ADT: UNION ALL of an adapter with typed literals (7.58); I_JournalEntry C1, elements AccountingDocument,
//             AccountingDocumentCreationDate, CreationTime, AccountingDocCreatedByUser, ReversalReason (VERIFY.md
//             V110).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Document-change model - events'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define view entity ZI_{{P}}_DocEvtAll
  as select from ZI_{{P}}_DocEvent as Evt
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
#if LEDGER
union all select from ZI_{{P}}_LedgPayBat as Pay
  inner join          ZI_{{P}}_LedgGlDoc  as Doc on  Doc.BatchKey    = Pay.BatchKey
                                                 and Doc.CompanyCode = Pay.CompanyCode
  inner join          I_JournalEntry      as Rev on  Rev.CompanyCode        = Doc.CompanyCode
                                                 and Rev.AccountingDocument = Doc.ReversalDocument
                                                 and Rev.FiscalYear         = Doc.ReversalYear
{
  key Pay.PaymentDocument,
  key cast( 'GL_REVERSAL' as abap.char( 16 ) )              as EventType,
  key cast( Rev.AccountingDocument as abap.char( 20 ) )     as EventDocument,
      Doc.CompanyCode,
      cast( Doc.GlDocument as abap.char( 20 ) )             as OriginalDocument,
      cast( '' as abap.char( 20 ) )                         as NewDocument,
      cast( Rev.AccountingDocument as abap.char( 20 ) )     as ReversalDocument,
      Rev.AccountingDocumentCreationDate                    as EventDate,
      Rev.CreationTime                                      as EventTime,
      Rev.AccountingDocCreatedByUser                        as EventUser,
      Rev.ReversalReason                                    as Reason,
      cast( 'GL' as abap.char( 10 ) )                       as EventSource
}
where
  Doc.IsReversed = 'X'
#endif

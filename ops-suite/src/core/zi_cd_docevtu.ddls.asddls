// Artifact: zi_cd_docevtu.ddls.asddls
// Purpose: Document-change events of the payment engine for the payment model (section document_event of
//          config/payment_model/mapping.json, build C): UNION ALL of
//          REVERSAL - a payment document reversed in the payment engine: the payment's document header (DFKKKO) carries
//                     the reversal document in STBEL (the reversal evidence of the trace, Payment_Trace.md section 4.2,
//                     and of the snapshot source REVERSALS); date / time / user of the reversal document's header;
//          VOID     - a cheque payment stopped (DPAYH-ZZ_PAYMENT_STATUS STOPPED, confirmed 2026-11-08); the status change
//                     time is not stored, so the date is the run date of the payment; the reissue is a separate payment
//                     with a new payment document and cheque number (confirmed) - its link to the stopped one needs the
//                     clearing history (not built, see below).
//          Payments are those of ZI_CD_PayLifeRun (newest run per payment document, 45-day run-date window - one row per
//          document). NOT here: clearing reset / re-clearing / reissue link (clearing-reset history TRACE_SRC_HISTORY,
//          candidate DFKKRAPT with the reset date / time - VERIFY-SE11, inactive until confirmed: design in
//          Dashboard_Production_Support.md section 9); returns (DFKKRP) stay the returns evidence, not a change event.
//          Read-only.
// Modification log: 2026-11-11 | Initial version (reversal and reset-clearing tracking, build C).
// VERIFY-SE11: DFKKKO-STBEL (reversal document), CPUDT, CPUTM (as the snapshot source REVERSALS), ERNAM (user of the
//              reversal document - not read elsewhere in the suite).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment model - document-change events'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define view entity ZI_CD_DocEvtU
  as select from ZI_CD_PayLifeRun as Pay
    inner join   dfkkko           as Org on Org.opbel = Pay.PaymentDocument
    inner join   dfkkko           as Rev on Rev.opbel = Org.stbel
{
  key cast( Pay.PaymentDocument as abap.char( 20 ) )        as PaymentDocument,
  key cast( 'REVERSAL' as abap.char( 16 ) )                 as EventType,
  key cast( Rev.opbel as abap.char( 20 ) )                  as EventDocument,
      Pay.CompanyCode,
      cast( Org.opbel as abap.char( 20 ) )                  as OriginalDocument,
      cast( '' as abap.char( 20 ) )                         as NewDocument,
      cast( Rev.opbel as abap.char( 20 ) )                  as ReversalDocument,
      Rev.cpudt                                             as EventDate,
      Rev.cputm                                             as EventTime,
      cast( Rev.ernam as abap.char( 12 ) )                  as EventUser,
      cast( '' as abap.char( 4 ) )                          as Reason,
      cast( 'SUBLEDGER' as abap.char( 10 ) )                as EventSource
}
where
  Org.stbel <> ''
union all select from ZI_CD_PayLifeRun as Pay
{
  key cast( Pay.PaymentDocument as abap.char( 20 ) )        as PaymentDocument,
  key cast( 'VOID' as abap.char( 16 ) )                     as EventType,
  key cast( Pay.PaymentDocument as abap.char( 20 ) )        as EventDocument,
      Pay.CompanyCode,
      cast( Pay.PaymentDocument as abap.char( 20 ) )        as OriginalDocument,
      cast( '' as abap.char( 20 ) )                         as NewDocument,
      cast( '' as abap.char( 20 ) )                         as ReversalDocument,
      Pay.BusinessDate                                      as EventDate,
      cast( '000000' as abap.tims )                         as EventTime,
      cast( '' as abap.char( 12 ) )                         as EventUser,
      cast( '' as abap.char( 4 ) )                          as Reason,
      cast( 'PAYMENT' as abap.char( 10 ) )                  as EventSource
}
where
  Pay.PaymentStatus = 'STOPPED'

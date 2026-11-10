// Artifact: zr_cd_trxreqflow.ddls.asddls
// Purpose: Request funnel of the transactions dashboard (ADT only, cds/ - activated after SE11
//          confirmation of the placeholders in ZI_CD_TrxReqLog, ZI_CD_TrxAckU, ZI_CD_TrxChqStat,
//          ZI_CD_TrxRtrv): one row per payment request and payment - FIN + source + company code +
//          payment document (+ method) - of the chosen request date(s) (the 45-day evidence window; the
//          SUCCESS row rule judges every attempt first, the window selects the requests afterwards)
//          with the stage it reached. The stage of a paid request is its current row of the payment
//          worklist (ZI_CD_PayWorkItem, joined by FIN + source + company code + payment document - the
//          same verdict as the morning report check A_INFLIGHT and the payment trace), never
//          re-derived from evidence here. A finished clean payment has no worklist row (user
//          decision 2026-11-08): its stage is the evidence stage below (PAID / ACKNOWLEDGED; the
//          payment trace shows its outcome). Requests not paid on their due date: src/core
//          ZR_CD_TrxFlow (kind REQUEST) and the morning report check A_PRQ_NOT_PAID.
//            ERRORED      no SUCCESS attempt, a failure value       PENDING   no SUCCESS, no failure
//            AMBIGUOUS    the FIN is in two or more sources (ZI_CD_TrxFinSrc) - never one picked
//            NOT_POSTED   SUCCESS, no open item with the FIN
//            REVERSED     clearing reason 05
//            <outcome>    worklist row: IN_FLIGHT / PENDING / UNDETERMINED / INCONSISTENT /
//                         AMBIGUOUS (canonical; a clean final payment has no row)
//            REJECTED     no outcome yet: NACK on the payment, or IRIS cheque status 3 / 4
//            ACKNOWLEDGED no outcome yet, ACK      PAID  payment run / cheque, no outcome, no ACK
//            POSTED       open item                OFFSET  cleared without payment run
//          A retrieval (ZCD_ACH_RTRV_LOG) is shown, never counted as a return. No member number.
//          Read-only.
// Modification log: 2026-11-06 | Initial version (transactions dashboard, request side).
//                   2026-11-07 | Review defects: joined on FinId only and RETURNED when IsReturned > 0 OR
//                   RetrievalCount > 0 - identity is now FIN + source + company code + payment and the
//                   stage is the canonical outcome (a retrieval is RETRIEVED, not RETURNED); request date
//                   window after the SUCCESS rule; "as of" parameters.
//                   2026-11-08 | Exceptions-only worklist: the current worklist row instead of the outcome
//                   "as of" an instant (parameters removed); request date window = evidence window;
//                   cleared / returned / retrieved counts removed (a clean payment has no row).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Transactions dashboard - request funnel'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #L, dataClass: #MIXED }
define root view entity ZR_CD_TrxReqFlow
  with parameters
    @EndUserText.label: 'Request date from'
    @Environment.systemField: #SYSTEM_DATE
    P_DateFrom : abap.dats,
    @EndUserText.label: 'Request date to'
    @Environment.systemField: #SYSTEM_DATE
    P_DateTo   : abap.dats
  as select from    ZI_CD_TrxReqSap( P_DateFrom : $parameters.P_DateFrom,
                                     P_DateTo   : $parameters.P_DateTo ) as Req
    left outer join ZI_CD_PayWorkItem as Out on  Out.FinId        = Req.FinId
                                         and Out.SourceSystem = Req.SourceSystem
                                         and Out.CompanyCode  = Req.CompanyCode
                                         and Out.ClearingDoc  = Req.ClearingDoc
    left outer join ZI_CD_TrxAck     as Ack  on Ack.PaymentDocument  = Req.ClearingDoc
    left outer join ZI_CD_TrxRtrv    as Rtrv on Rtrv.PaymentDocument = Req.ClearingDoc
    left outer join ZI_CD_TrxChqPay  as Chq  on Chq.PaymentDocument  = Req.ClearingDoc
{
  key Req.FinId,
  key Req.SourceSystem,
  key Req.CompanyCode,
  key Req.ClearingDoc,
  key Req.PaymentMethod,
      cast( 'CD_OPS' as abap.char( 16 ) )                      as PaymentEngineArea,
      Req.RequestDate,
      Req.LastAttemptDate,
      Req.RequestOutcome,
      Req.Direction,
      Req.PostingDate,
      Req.SourceCount,
      Rtrv.RetrievalStatus,
      Out.Outcome,
      Out.Finding                                           as OutcomeFinding,
      Out.EvidenceKind                                      as OutcomeEvidenceKind,
      Out.EvidenceRef                                       as OutcomeEvidenceRef,
      Out.ValidFrom                                         as OutcomeValidFrom,
      cast( case
              when Req.RequestOutcome = 'ERRORED'                     then 'ERRORED'
              when Req.RequestOutcome = 'PENDING'                     then 'PENDING'
              when Req.SourceCount > 1                                then 'AMBIGUOUS'
              when Req.IsPosted = ' '                                 then 'NOT_POSTED'
              when Req.IsReversed > 0                                 then 'REVERSED'
              when Out.Outcome is not null                            then Out.Outcome
              when Ack.NackCount > 0 or Chq.IsFailed > 0              then 'REJECTED'
              when Ack.AckRowCount > 0                                then 'ACKNOWLEDGED'
              when Req.IsPaid > 0                                     then 'PAID'
              when Req.HasOpenItem > 0                                then 'POSTED'
              else 'OFFSET' end as abap.char( 20 ) )        as RequestStage,
      cast( case
              when Req.RequestOutcome = 'ERRORED'                     then 1
              when Req.SourceCount > 1                                then 1
              when Out.Severity = 'E'                                 then 1
              when Out.Outcome is null and ( Ack.NackCount > 0 or Chq.IsFailed > 0 ) then 1
              when Out.Finding <> ' '                                 then 2
              else 0 end as abap.int1 )                     as StageCriticality,
      // ---------------------------------------------------------------- funnel measures (reached)
      cast( 1 as abap.int4 )                                as RequestedCount,
      cast( case Req.RequestOutcome when 'PROCESSED' then 1 else 0 end as abap.int4 ) as ProcessedCount,
      cast( case Req.RequestOutcome when 'ERRORED' then 1 else 0 end as abap.int4 )   as ErroredCount,
      cast( case Req.IsPosted when 'X' then 1 else 0 end as abap.int4 )               as PostedCount,
      cast( case when Req.IsPaid > 0 then 1 else 0 end as abap.int4 )                 as PaidCount,
      cast( case when Ack.AckRowCount > 0 then 1 else 0 end as abap.int4 )            as AcknowledgedCount,
      cast( case when Ack.NackCount > 0 then 1 else 0 end as abap.int4 )              as RejectedCount,
      cast( case when Out.Finding <> ' ' then 1 else 0 end as abap.int4 )            as ExceptionCount,
      cast( case when Req.SourceCount > 1 then 1 else 0 end as abap.int4 )            as AmbiguousCount,
      Req.AttemptCount,
      Req.SuccessAttempts,
      Req.ErrorAttempts
}

// Artifact: zr_cd_trxreqflow.ddls.asddls
// Purpose: Request funnel of the transactions dashboard (ADT only, cds/ - activated after SE11
//          confirmation of the placeholders in ZI_CD_TrxReqLog, ZI_CD_TrxAckU, ZI_CD_TrxChqStat,
//          ZI_CD_TrxRtrv): one row per payment request (FIN + source, last 31 days) with the stage
//          it reached - requested (ZCD_PAYM_REQ_LOG, SUCCESS row rule) -> posted (open item) ->
//          paid (payment run / cheque) -> acknowledged (ACK) -> settled / encashed, or errored /
//          rejected / returned. Stage (current position, terminal first):
//            ERRORED      no SUCCESS attempt, a failure value       PENDING   no SUCCESS, no failure
//            NOT_POSTED   SUCCESS, no open item with the FIN in the 31-day window
//            RETURNED     returns lot item, retrieval, or cheque status 9
//            REJECTED     NACK on the payment, or cheque status 3 / 4
//            REVERSED     clearing reason 05
//            SETTLED      bank line on the payment / cheque          ACKNOWLEDGED  ACK, no bank line yet
//            PAID         payment run / cheque, no ACK yet           CLEARED / POSTED as ZR_CD_TrxFlow
//          The FIN is matched to DFKKOP-ZZ_FIN_TRANS_NUM without the source (DFKKOP has no source
//          field); the payment trace (FIN + source) resolves ambiguity. No member number. Read-only.
// Modification log: 2026-11-06 | Initial version (transactions dashboard, request side).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Transactions dashboard - request funnel'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #L, dataClass: #MIXED }
define root view entity ZR_CD_TrxReqFlow
  as select from    ZI_CD_TrxRequest as Req
    left outer join ZI_CD_TrxFinFlow as Sap  on Sap.FinId = Req.FinId
    left outer join ZI_CD_TrxAck     as Ack  on Ack.PaymentDocument = Sap.ClearingDoc
    left outer join ZI_CD_TrxRtrv    as Rtrv on Rtrv.PaymentDocument = Sap.ClearingDoc
    left outer join ZI_CD_TrxChqStat as Chq  on Chq.ChequeNo = Sap.ChequeNo
{
  key Req.FinId,
  key Req.SourceSystem,
      cast( 'CORE' as abap.char( 4 ) )                      as PaymentEngineArea,
      Req.RequestDate,
      Req.RequestOutcome,
      // Blank until the request is posted: visible to users with BUKRS * only (DCL)
      coalesce( Sap.CompanyCode, ' ' )                      as CompanyCode,
      Sap.PaymentMethod,
      Sap.Direction,
      Sap.PostingDate,
      Sap.ClearingDoc,
      Sap.ChequeNo,
      Rtrv.RetrievalStatus,
      cast( case
              when Req.RequestOutcome = 'ERRORED'                     then 'ERRORED'
              when Req.RequestOutcome = 'PENDING'                     then 'PENDING'
              when Sap.FinId is null                                  then 'NOT_POSTED'
              when Sap.IsReturned > 0 or Rtrv.RetrievalCount > 0
                or Chq.IsReturned > 0                                 then 'RETURNED'
              when Ack.NackCount > 0 or Chq.IsFailed > 0              then 'REJECTED'
              when Sap.IsReversed > 0                                 then 'REVERSED'
              when Sap.IsSettled > 0                                  then 'SETTLED'
              when Ack.AckRowCount > 0                                then 'ACKNOWLEDGED'
              when Sap.IsPaid > 0                                     then 'PAID'
              when Sap.HasOpenItem > 0                                then 'POSTED'
              else 'CLEARED' end as abap.char( 12 ) )       as RequestStage,
      cast( case
              when Req.RequestOutcome = 'ERRORED'                     then 1
              when Sap.IsReturned > 0 or Rtrv.RetrievalCount > 0
                or Chq.IsReturned > 0                                 then 1
              when Ack.NackCount > 0 or Chq.IsFailed > 0              then 1
              when Sap.IsSettled > 0                                  then 3
              else 0 end as abap.int1 )                     as StageCriticality,
      // ---------------------------------------------------------------- funnel measures (reached)
      cast( 1 as abap.int4 )                                as RequestedCount,
      cast( case Req.RequestOutcome when 'PROCESSED' then 1 else 0 end as abap.int4 ) as ProcessedCount,
      cast( case Req.RequestOutcome when 'ERRORED' then 1 else 0 end as abap.int4 )   as ErroredCount,
      cast( case when Sap.FinId is not null then 1 else 0 end as abap.int4 )          as PostedCount,
      cast( coalesce( Sap.IsPaid, 0 ) as abap.int4 )                                  as PaidCount,
      cast( case when Ack.AckRowCount > 0 then 1 else 0 end as abap.int4 )            as AcknowledgedCount,
      cast( case when Ack.NackCount > 0 then 1 else 0 end as abap.int4 )              as RejectedCount,
      cast( coalesce( Sap.IsSettled, 0 ) as abap.int4 )                               as SettledCount,
      cast( case when Sap.IsReturned > 0 or Rtrv.RetrievalCount > 0 or Chq.IsReturned > 0
                 then 1 else 0 end as abap.int4 )                                     as ReturnedCount,
      Req.AttemptCount,
      Req.SuccessAttempts,
      Req.ErrorAttempts
}

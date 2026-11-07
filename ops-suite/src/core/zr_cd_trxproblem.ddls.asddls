// Artifact: zr_cd_trxproblem.ddls.asddls
// Purpose: "Errored / stuck" list of the transactions dashboard (launchpad list tile and the
//          production-support overview page list card): transactions of the last 31 days whose
//          current canonical outcome (ZI_CD_TrxItemFlow, as of now) is RETURNED, INCONSISTENT,
//          UNDETERMINED or AMBIGUOUS, items REVERSED (clearing reason 05), and disbursements still
//          OPEN_OVERDUE (no clearing document, posted before yesterday - the hourly payment runs
//          should have paid them). A retrieval is not listed as a return. Errored payment requests
//          (no SUCCESS row) are in cds/ ZR_CD_TrxReqFlow. Newest first. Read-only.
// Modification log: 2026-11-06 | Initial version (transactions dashboard).
//                   2026-11-07 | Canonical outcome (problem outcomes); 31-day window here.
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Transactions dashboard - errored / stuck'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #M, dataClass: #MIXED }
define root view entity ZR_CD_TrxProblem
  as select from ZI_CD_TrxItemFlow( P_AsOfDate : $session.system_date,
                                    P_AsOfTime : '235959' ) as Flow
{
  key Flow.DocumentNo,
  key Flow.RepetitionItem,
  key Flow.ItemNo,
  key Flow.SubItem,
      Flow.PaymentEngineArea,
      Flow.FinId,
      Flow.CompanyCode,
      Flow.PostingDate,
      Flow.PaymentMethod,
      Flow.Direction,
      Flow.ClearingDoc,
      Flow.ClearingDate,
      Flow.PaymentStatus,
      Flow.ReturnReason,
      Flow.FlowBucket,
      Flow.OutcomeFinding,
      cast( case
              when Flow.FlowBucket = 'POSTED' then 'OPEN_OVERDUE'
              else Flow.FlowBucket end as abap.char( 20 ) ) as ProblemType,
      cast( case
              when Flow.FlowBucket = 'POSTED' then 2
              when Flow.FlowBucket = 'UNDETERMINED' then 2
              else 1 end as abap.int1 )                     as ProblemCriticality,
      Flow.Currency,
      @Semantics.amount.currencyCode: 'Currency'
      Flow.Amount
}
where Flow.PostingDate >= dats_add_days( $session.system_date, -30, 'INITIAL' )
  and ( Flow.FlowBucket = 'RETURNED'
     or Flow.FlowBucket = 'REVERSED'
     or Flow.FlowBucket = 'INCONSISTENT'
     or Flow.FlowBucket = 'UNDETERMINED'
     or Flow.FlowBucket = 'AMBIGUOUS'
     or ( Flow.FlowBucket  = 'POSTED'
      and Flow.Direction   = 'DISBURSEMENT'
      and Flow.PostingDate < dats_add_days( $session.system_date, -1, 'INITIAL' ) ) )

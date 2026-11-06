// Artifact: zr_cd_trxproblem.ddls.asddls
// Purpose: "Errored / stuck" list of the transactions dashboard (launchpad list tile and the
//          production-support overview page list card): transactions of the last 31 days that were
//          RETURNED (returns lot item, reason DFKKRP-RLGRD), REVERSED (clearing reason 05), or are
//          disbursements still OPEN_OVERDUE (no clearing document, posted before yesterday - the
//          hourly payment runs should have paid them). Errored payment requests (no SUCCESS row)
//          are in cds/ ZR_CD_TrxReqFlow. Newest first. Read-only.
// Modification log: 2026-11-06 | Initial version (transactions dashboard).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Transactions dashboard - errored / stuck'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #M, dataClass: #MIXED }
define root view entity ZR_CD_TrxProblem
  as select from ZR_CD_TrxFlow
{
  key DocumentNo,
  key RepetitionItem,
  key ItemNo,
  key SubItem,
      PaymentEngineArea,
      FinId,
      CompanyCode,
      PostingDate,
      PaymentMethod,
      Direction,
      ClearingDoc,
      ClearingDate,
      PaymentStatus,
      ReturnReason,
      FlowBucket,
      cast( case
              when FlowBucket = 'RETURNED' then 'RETURNED'
              when FlowBucket = 'REVERSED' then 'REVERSED'
              else 'OPEN_OVERDUE' end as abap.char( 12 ) )  as ProblemType,
      cast( case
              when FlowBucket = 'RETURNED' then 1
              when FlowBucket = 'REVERSED' then 1
              else 2 end as abap.int1 )                     as ProblemCriticality,
      Currency,
      @Semantics.amount.currencyCode: 'Currency'
      Amount
}
where FlowBucket = 'RETURNED'
   or FlowBucket = 'REVERSED'
   or ( FlowBucket  = 'POSTED'
    and Direction   = 'DISBURSEMENT'
    and PostingDate < dats_add_days( $session.system_date, -1, 'INITIAL' ) )

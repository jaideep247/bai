// Artifact: zi_ca_opsreconalert.ddls.asddls
// Purpose: Alert reconciliation, second and third leg (build O, docs/EVALUATION_AND_COVERAGE.md section 4): per run,
//          the routing decisions of the alert router (ZCA_OPS_ALLOG rows), the alerts submitted (S, P), failed at
//          submission (F), held back on purpose (T throttled, Q quiet hours, R repeat, D planned downtime, K
//          correlated) or still claimed (C) - and of the submitted ones the delivery state: delivered (D), pending
//          (P or not asked yet), failed after submission (F), the channel cannot confirm (N). Submission is never
//          counted as delivery. Nothing stored, read-only.
// Modification log: 2026-11-16 | Initial version (build O: alert delivery reconciliation).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Alert reconciliation: alerts per run'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #M, dataClass: #TRANSACTIONAL }
define view entity ZI_CA_OpsReconAlert
  as select from zca_ops_allog as Log
{
  key Log.run_id                                            as RunId,
      cast( count( * ) as abap.int4 )                       as DecisionCount,
      cast( sum( case when Log.status = 'S' or Log.status = 'P' then 1 else 0 end ) as abap.int4 ) as SubmittedCount,
      cast( sum( case when Log.status = 'F' then 1 else 0 end ) as abap.int4 ) as SubmitFailedCount,
      cast( sum( case when Log.status = 'T' or Log.status = 'Q' or Log.status = 'R' or Log.status = 'D'
                        or Log.status = 'K' then 1 else 0 end ) as abap.int4 ) as SuppressedCount,
      cast( sum( case when Log.status = 'C' then 1 else 0 end ) as abap.int4 ) as ClaimedCount,
      cast( sum( case when ( Log.status = 'S' or Log.status = 'P' ) and Log.dlv_state = 'D'
                      then 1 else 0 end ) as abap.int4 )    as DeliveredCount,
      cast( sum( case when ( Log.status = 'S' or Log.status = 'P' )
                       and ( Log.dlv_state = 'P' or Log.dlv_state = ' ' )
                      then 1 else 0 end ) as abap.int4 )    as PendingCount,
      cast( sum( case when ( Log.status = 'S' or Log.status = 'P' ) and Log.dlv_state = 'F'
                      then 1 else 0 end ) as abap.int4 )    as DeliveryFailedCount,
      cast( sum( case when ( Log.status = 'S' or Log.status = 'P' ) and Log.dlv_state = 'N'
                      then 1 else 0 end ) as abap.int4 )    as CannotConfirmCount
}
group by
  Log.run_id

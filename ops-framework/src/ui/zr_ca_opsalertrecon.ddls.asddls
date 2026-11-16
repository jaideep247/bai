// Artifact: zr_ca_opsalertrecon.ddls.asddls
// Purpose: Alert reconciliation per run of the last 7 days (build O, docs/EVALUATION_AND_COVERAGE.md section 4):
//          findings that should have alerted (owned exceptions of the run) versus alerts submitted versus alerts
//          delivered, with the decisions in between (held back on purpose, failed at submission, still claimed) and
//          the delivery state of the submitted ones (pending, failed after submission, channel cannot confirm).
//          State, worst first: FAILED (a submission or a delivery failed), PENDING (submitted, not confirmed yet),
//          UNCONFIRM (the channel cannot confirm), NOT_ROUTED (exceptions but no routing decision at all - no rule
//          took them), DELIVERED (every submitted alert confirmed), NONE (nothing to alert). Test-mode runs are left
//          out. Nothing stored, read-only (no behaviour definition).
// Modification log: 2026-11-16 | Initial version (build O: alert delivery reconciliation).
// VERIFY-ADT (V278): comparison of TIMESTAMPL with the cast of tstmp_add_seconds (as ZI_CA_OpsCtlRunDay).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Alert reconciliation per run'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #M, dataClass: #TRANSACTIONAL }
define root view entity ZR_CA_OpsAlertRecon
  as select from    zca_ops_run         as Run
    left outer join ZI_CA_OpsReconFind  as Fd on Fd.RunId = Run.run_id
    left outer join ZI_CA_OpsReconAlert as Al on Al.RunId = Run.run_id
{
  key Run.run_id                                            as RunId,
      Run.area                                              as Area,
      Run.variant                                           as Variant,
      Run.started_at                                        as StartedAt,
      Run.rag                                               as RunRag,
      cast( coalesce( Fd.ExceptionCount, 0 ) as abap.int4 ) as ExceptionCount,
      cast( coalesce( Fd.BlockingCount, 0 ) as abap.int4 )  as BlockingCount,
      cast( coalesce( Al.DecisionCount, 0 ) as abap.int4 )  as DecisionCount,
      cast( coalesce( Al.SubmittedCount, 0 ) as abap.int4 ) as SubmittedCount,
      cast( coalesce( Al.DeliveredCount, 0 ) as abap.int4 ) as DeliveredCount,
      cast( coalesce( Al.PendingCount, 0 ) as abap.int4 )   as PendingCount,
      cast( coalesce( Al.CannotConfirmCount, 0 ) as abap.int4 ) as CannotConfirmCount,
      cast( coalesce( Al.DeliveryFailedCount, 0 ) as abap.int4 ) as DeliveryFailedCount,
      cast( coalesce( Al.SubmitFailedCount, 0 ) as abap.int4 ) as SubmitFailedCount,
      cast( coalesce( Al.SuppressedCount, 0 ) as abap.int4 ) as SuppressedCount,
      cast( coalesce( Al.ClaimedCount, 0 ) as abap.int4 )   as ClaimedCount,
      cast( case
              when coalesce( Al.SubmitFailedCount, 0 ) + coalesce( Al.DeliveryFailedCount, 0 ) > 0 then 'FAILED'
              when coalesce( Al.PendingCount, 0 ) + coalesce( Al.ClaimedCount, 0 ) > 0 then 'PENDING'
              when coalesce( Al.CannotConfirmCount, 0 ) > 0 then 'UNCONFIRM'
              when coalesce( Fd.ExceptionCount, 0 ) > 0 and coalesce( Al.DecisionCount, 0 ) = 0 then 'NOT_ROUTED'
              when coalesce( Al.SubmittedCount, 0 ) > 0 then 'DELIVERED'
              else 'NONE' end as abap.char( 10 ) )          as ReconState,
      cast( case
              when coalesce( Al.SubmitFailedCount, 0 ) + coalesce( Al.DeliveryFailedCount, 0 ) > 0 then 1
              when coalesce( Al.PendingCount, 0 ) + coalesce( Al.ClaimedCount, 0 ) > 0 then 2
              when coalesce( Al.CannotConfirmCount, 0 ) > 0 then 2
              when coalesce( Fd.ExceptionCount, 0 ) > 0 and coalesce( Al.DecisionCount, 0 ) = 0 then 2
              when coalesce( Al.SubmittedCount, 0 ) > 0 then 3
              else 0 end as abap.int1 )                     as ReconCriticality
}
where
      Run.test_mode  =  ' '
  and Run.started_at >= cast( tstmp_add_seconds( tstmp_current_utctimestamp(),
                                                 cast( -604800 as abap.dec( 15, 0 ) ), 'INITIAL' )
                              as abap.dec( 21, 7 ) )

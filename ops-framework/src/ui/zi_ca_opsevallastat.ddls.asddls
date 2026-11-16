// Artifact: zi_ca_opsevallastat.ddls.asddls
// Purpose: Time of the latest evaluation record of every registered check (ZCA_OPS_EVAL, written by the runner for
//          every check and run - also for a check not run; build O, docs/EVALUATION_AND_COVERAGE.md). Index LST
//          (AREA, CHECK_ID, EVALUATED_AT). Nothing stored, read-only.
// Modification log: 2026-11-16 | Initial version (build O: evaluation state of every control).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Evaluation: latest time per check'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #M, dataClass: #TRANSACTIONAL }
define view entity ZI_CA_OpsEvalLastAt
  as select from zca_ops_eval as Ev
{
  key Ev.area                                               as Area,
  key Ev.check_id                                           as CheckId,
      max( Ev.evaluated_at )                                as LastEvaluatedAt
}
group by
  Ev.area,
  Ev.check_id

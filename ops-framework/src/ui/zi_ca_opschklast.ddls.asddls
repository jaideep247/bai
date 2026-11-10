// Artifact: zi_ca_opschklast.ddls.asddls
// Purpose: Start of the latest completed run per area and run variant (= schedule group of the check registry,
//          ZCL_CA_OPS_CHECK_RUNNER): runs in status R (running) and test-mode runs are left out. Index MOD of
//          ZCA_OPS_RUN (AREA, STARTED_AT); runs are few (one per job and schedule). Read-only.
// Modification log: 2026-11-10 | Initial version (process onboarding: area dashboard and freshness).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Area dashboard: latest run per group'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #M, dataClass: #TRANSACTIONAL }
define view entity ZI_CA_OpsChkLast
  as select from zca_ops_run as Run
{
  key Run.area                                              as Area,
  key Run.variant                                           as Variant,
      max( Run.started_at )                                 as LastRunAt
}
where
      Run.status    <> 'R'
  and Run.test_mode =  ' '
group by
  Run.area,
  Run.variant

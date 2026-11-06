// Artifact: zi_cd_opsrun.ddls.asddls
// Purpose: Basic interface view over ZCD_OPS_RUN (run headers of HCK, FMON, EBS)
//          for the operations dashboard. Release-dependent annotations: verify on target release.
// Modification log: 2026-11-05 | Initial version (ops suite consolidation).
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Ops suite run (basic)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #M, dataClass: #TRANSACTIONAL }
@VDM.viewType: #BASIC
define view entity ZI_CD_OpsRun
  as select from zcd_ops_run
{
  key run_id                                              as RunId,
      module                                              as Module,
      variant                                             as Variant,
      test_mode                                           as IsTestMode,
      started_at                                          as StartedAt,
      ended_at                                            as EndedAt,
      // verify on target release: TIMESTAMPL -> TIMESTAMP cast, UTC calendar day
      tstmp_to_dats( cast( started_at as timestamp ), 'UTC', $session.client, 'NULL' ) as RunDate,
      status                                              as RunStatus,
      rag                                                 as Rag,
      total_items                                         as TotalItems,
      passed_items                                        as PassedItems,
      failed_items                                        as FailedItems,
      warning_items                                       as WarningItems,
      finding_count                                       as FindingCount,
      runtime_ms                                          as RuntimeMs,
      message                                             as RunMessage,
      created_by                                          as CreatedBy
}

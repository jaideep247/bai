// Artifact: zi_cd_hckresult.ddls.asddls
// Purpose: Basic view of the persisted verdict of each check in each morning report run
//          (ZCD_HCK_RESULT, written by ZCL_CD_HCK_ENGINE from the decision the report uses):
//          check status (RED, AMBER, GREEN, WARMUP, GREY, FAILED, SKIPPED), completion,
//          evidence availability, run scope, counts, baseline mode, summary. The health check
//          dashboard reads the verdict here and never re-derives it from metrics and findings.
//          Read-only.
// Modification log: 2026-11-07 | Initial version (design review: persisted check verdicts).
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'HCK check verdict per run'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #L, dataClass: #TRANSACTIONAL }
@VDM.viewType: #BASIC
define view entity ZI_CD_HckResult
  as select from zcd_hck_result
{
  key run_id                                                as RunId,
  key check_id                                              as CheckId,
      executed_at                                           as ExecutedAt,
      category                                              as Category,
      priority                                              as Priority,
      verdict                                               as Verdict,
      check_status                                          as CheckStatus,
      completion                                            as Completion,
      evidence                                              as EvidenceAvailability,
      run_scope                                             as RunScope,
      metric_count                                          as MetricCount,
      finding_count                                         as RunFindingCount,
      error_count                                           as ErrorCount,
      warning_count                                         as WarningCount,
      baseline_mode                                         as BaselineMode,
      warmup                                                as IsWarmup,
      runtime_ms                                            as RuntimeMs,
      message                                               as ResultMessage
}

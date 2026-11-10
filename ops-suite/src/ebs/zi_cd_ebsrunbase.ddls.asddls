// Artifact: zi_cd_ebsrunbase.ddls.asddls
// Purpose: Basic view of EBS validation runs (ZCA_OPS_RUN, area EBS, not test mode) started in
//          the last 31 days (bounded read), with the run date (UTC calendar day of the start),
//          the completed flag and the line counters written by ZCL_CD_EBS_ENGINE->COUNT_LINES:
//          total = lines validated, passed, warning, failed (incl. lines of a rule group whose
//          rule had a PLUGIN_ERROR), blocked. A line expected to post but not posted is counted
//          in none of them (operating model 2026-11-06), so Unevaluated = total - the four.
//          Read-only.
// Modification log: 2026-11-06 | Initial version (EBS validation dashboard).
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'EBS validation run (basic)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #M, dataClass: #TRANSACTIONAL }
@VDM.viewType: #BASIC
define view entity ZI_CD_EbsRunBase
  as select from zca_ops_run
{
  key run_id                                                as RunId,
      cast( 'CD_EBS' as abap.char( 16 ) )                       as PaymentEngineArea,
      variant                                               as RunVariant,
      started_at                                            as StartedAt,
      ended_at                                              as EndedAt,
      // VERIFY-ADT: TIMESTAMPL -> TIMESTAMP cast, UTC calendar day (as ZI_CD_OpsRun)
      tstmp_to_dats( cast( started_at as timestamp ), 'UTC', $session.client, 'NULL' ) as RunDate,
      status                                                as RunStatus,
      rag                                                   as RunRag,
      // Completed: S, W, E or N (no data); R running and A aborted are listed, never counted as a look
      case when status = 'S' or status = 'W' or status = 'E' or status = 'N'
           then cast( 'X' as abap_boolean )
           else cast( ' ' as abap_boolean ) end             as IsCompleted,
      total_items                                           as LineCount,
      passed_items                                          as PassedLineCount,
      warning_items                                         as WarningLineCount,
      failed_items                                          as FailedLineCount,
      blocked_items                                         as BlockedLineCount,
      cast( total_items - passed_items - warning_items - failed_items - blocked_items as abap.int4 ) as UnevaluatedLineCount,
      finding_count                                         as RunFindingCount,
      runtime_ms                                            as RuntimeMs,
      message                                               as RunMessage
}
where area   = 'CD_EBS'
  and test_mode = ' '
  and tstmp_to_dats( cast( started_at as timestamp ), 'UTC', $session.client, 'NULL' )
      >= dats_add_days( $session.system_date, -31, 'INITIAL' )

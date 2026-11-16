// Artifact: zi_ca_opsevallast.ddls.asddls
// Purpose: The latest evaluation record of every registered check (build O, docs/EVALUATION_AND_COVERAGE.md):
//          expected scope (business date, period, company codes), source freshness and its source, watermark,
//          completeness, result class, the display state support sees (not evaluated, stale, partial before
//          anything green), reason, licence state of the run and the last valid (complete) result. MAX( RunId )
//          only decides between two records of the same instant. The area dashboard, the coverage view and the
//          consumers' cards read it. Nothing stored, read-only.
// Modification log: 2026-11-16 | Initial version (build O: evaluation state of every control).
// VERIFY-ADT (V276): MAX on a RAW 16 element and on CHAR elements in one aggregation (7.58).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Evaluation: latest record per check'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #M, dataClass: #TRANSACTIONAL }
define view entity ZI_CA_OpsEvalLast
  as select from ZI_CA_OpsEvalLastAt as La
    inner join   zca_ops_eval        as Ev on  Ev.area         = La.Area
                                           and Ev.check_id     = La.CheckId
                                           and Ev.evaluated_at = La.LastEvaluatedAt
{
  key La.Area                                               as Area,
  key La.CheckId                                            as CheckId,
      La.LastEvaluatedAt                                    as EvaluatedAt,
      max( Ev.run_id )                                      as RunId,
      max( Ev.bus_date )                                    as BusinessDate,
      max( Ev.period )                                      as Period,
      max( Ev.bukrs_list )                                  as CompanyCodes,
      max( Ev.expected_cnt )                                as ExpectedCount,
      max( Ev.observed_cnt )                                as ObservedCount,
      max( Ev.finding_cnt )                                 as ExceptionCount,
      max( Ev.completeness )                                as Completeness,
      max( Ev.result_class )                                as ResultClass,
      max( Ev.eval_state )                                  as EvaluationState,
      max( Ev.reason_code )                                 as ReasonCode,
      max( Ev.reason )                                      as Reason,
      max( Ev.fresh_at )                                    as SourceFreshAt,
      max( Ev.fresh_source )                                as FreshSource,
      max( Ev.watermark )                                   as Watermark,
      max( Ev.lic_state )                                   as LicenceState,
      max( Ev.lic_module )                                  as LicenceModule,
      max( Ev.last_valid_at )                               as LastValidAt,
      max( Ev.last_valid_cls )                              as LastValidResult
}
group by
  La.Area,
  La.CheckId,
  La.LastEvaluatedAt

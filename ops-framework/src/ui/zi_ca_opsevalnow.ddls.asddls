// Artifact: zi_ca_opsevalnow.ddls.asddls
// Purpose: Evaluation state of every registered check now (build O, docs/EVALUATION_AND_COVERAGE.md): its latest
//          evaluation record (ZI_CA_OpsEvalLast) judged against its schedule window - the area dashboard's
//          freshness CHECK_STALE_MIN_<area>, else CHECK_STALE_MIN_DEFAULT: no record = NOT_EVAL, a record older
//          than the window = STALE, else the record's display state. Never green when unknown: IsUnknown for
//          NOT_EVAL, STALE and PARTIAL; criticality red for not evaluated / stale, amber for partial and findings,
//          neutral for a closed period, green for OK, valid zero volume and not expected. The rules of
//          ZCL_CA_OPS_EVAL=>IS_UNKNOWN and ZCL_CA_OPS_COVERAGE=>IN_WINDOW. Nothing stored, read-only.
// Modification log: 2026-11-16 | Initial version (build O: evaluation state of every control).
// VERIFY-ADT (V274): cross join with left outer joins and tstmp_seconds_between on the TIMESTAMPL cast (as
//             ZR_CA_OpsCheckStatus).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Evaluation: state of every check now'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #M, dataClass: #MIXED }
define view entity ZI_CA_OpsEvalNow
  as select from    zca_ops_check      as Chk
    cross join      ZI_CA_OpsChkStaleD as StD
    left outer join ZI_CA_OpsChkStaleA as StA on StA.Area = Chk.area
    left outer join ZI_CA_OpsEvalLast  as Ev  on  Ev.Area    = Chk.area
                                              and Ev.CheckId = Chk.check_id
{
  key Chk.area                                              as Area,
  key Chk.check_id                                          as CheckId,
      cast( coalesce( StA.StaleAfterMinutes, StD.StaleAfterMinutes ) as abap.int4 ) as WindowMinutes,
      Ev.EvaluatedAt,
      Ev.RunId,
      Ev.BusinessDate,
      Ev.Period,
      Ev.CompanyCodes,
      Ev.ExpectedCount,
      Ev.ObservedCount,
      Ev.ExceptionCount,
      Ev.Completeness,
      Ev.ResultClass,
      Ev.ReasonCode,
      Ev.Reason,
      Ev.SourceFreshAt,
      Ev.FreshSource,
      Ev.Watermark,
      Ev.LicenceState,
      Ev.LicenceModule,
      Ev.LastValidAt,
      Ev.LastValidResult,
      cast( case
              when Ev.EvaluatedAt is null then ' '
              when tstmp_seconds_between( cast( Ev.EvaluatedAt as timestamp ), tstmp_current_utctimestamp( ), 'NULL' )
                   > coalesce( StA.StaleAfterMinutes, StD.StaleAfterMinutes ) * 60 then ' '
              else 'X' end as abap_boolean )              as IsInWindow,
      cast( case
              when Ev.EvaluatedAt is null then 'NOT_EVAL'
              when tstmp_seconds_between( cast( Ev.EvaluatedAt as timestamp ), tstmp_current_utctimestamp( ), 'NULL' )
                   > coalesce( StA.StaleAfterMinutes, StD.StaleAfterMinutes ) * 60 then 'STALE'
              else Ev.EvaluationState end as zca_ops_eval_state ) as EvaluationState,
      cast( case
              when Ev.EvaluatedAt is null then 1
              when tstmp_seconds_between( cast( Ev.EvaluatedAt as timestamp ), tstmp_current_utctimestamp( ), 'NULL' )
                   > coalesce( StA.StaleAfterMinutes, StD.StaleAfterMinutes ) * 60 then 1
              when Ev.EvaluationState = 'NOT_EVAL' or Ev.EvaluationState = 'STALE' then 1
              when Ev.EvaluationState = 'PARTIAL' or Ev.EvaluationState = 'FINDINGS' then 2
              when Ev.EvaluationState = 'PER_CLOSED' then 0
              else 3 end as abap.int1 )                     as EvaluationCriticality,
      cast( case
              when Ev.EvaluatedAt is null then 'X'
              when tstmp_seconds_between( cast( Ev.EvaluatedAt as timestamp ), tstmp_current_utctimestamp( ), 'NULL' )
                   > coalesce( StA.StaleAfterMinutes, StD.StaleAfterMinutes ) * 60 then 'X'
              when Ev.EvaluationState = 'NOT_EVAL' or Ev.EvaluationState = 'STALE'
                or Ev.EvaluationState = 'PARTIAL' or Ev.EvaluationState = ' ' then 'X'
              else ' ' end as abap_boolean )               as IsUnknown
}

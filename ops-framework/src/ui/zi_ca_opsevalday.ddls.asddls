// Artifact: zi_ca_opsevalday.ddls.asddls
// Purpose: Latest evaluation of every registered check per business date of the daily review (build O,
//          docs/EVALUATION_AND_COVERAGE.md section 3): the record of the newest run of the date - the business date of
//          a run is its start as a local date of CONTROL_TIME_ZONE (ZI_CA_OpsCtlRunDay, 33 days, test mode left
//          out). Nothing stored, read-only.
// Modification log: 2026-11-16 | Initial version (build O: evaluation state of every control).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Evaluation: latest per check and date'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #M, dataClass: #TRANSACTIONAL }
define view entity ZI_CA_OpsEvalDay
  as select from zca_ops_eval       as Ev
    inner join   ZI_CA_OpsCtlRunDay as Rd on Rd.RunId = Ev.run_id
{
  key Ev.area                                               as Area,
  key Ev.check_id                                           as CheckId,
  key Rd.BusinessDate                                       as BusinessDate,
      max( Ev.evaluated_at )                                as LastEvaluatedAt
}
group by
  Ev.area,
  Ev.check_id,
  Rd.BusinessDate

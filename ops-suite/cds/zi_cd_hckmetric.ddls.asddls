// Artifact: zi_cd_hckmetric.ddls.asddls
// Purpose: Basic interface view over ZCD_HCK_METRIC (metric history: volumes,
//          durations, error rates) for trends. Verify annotations on target release.
// Modification log: 2026-11-05 | Initial version (ops suite consolidation).
//                   2026-11-06 | Metric kind and weight for aggregation by metric semantics (audit A88).
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Health check metric history (basic)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #L, dataClass: #TRANSACTIONAL }
@VDM.viewType: #BASIC
define view entity ZI_CD_HckMetric
  as select from zcd_hck_metric
{
  key run_id                                              as RunId,
  key check_id                                            as CheckId,
  key metric                                              as Metric,
  key dim1                                                as Dimension1,
  key dim2                                                as Dimension2,
      // constant payment engine area for the DCL (same authorization object as findings)
      cast( 'HCK' as abap.char(4) )                       as PaymentEngineArea,
      value                                               as MetricValue,
      // A88: V volume (SUM), L level - duration / age / size (MAX, AVG), R rate (weighted);
      // rows written before the field existed count as volumes
      case kind when 'L' then 'L' when 'R' then 'R' else 'V' end as MetricKind,
      // rates: denominator the rate was computed over (unknown = 1, i.e. unweighted)
      case when weight > 0 then weight else cast( 1 as abap.dec( 31, 4 ) ) end as Weight,
      measured_at                                         as MeasuredAt,
      // verify on target release: TIMESTAMPL -> TIMESTAMP cast, UTC calendar day
      tstmp_to_dats( cast( measured_at as timestamp ), 'UTC', $session.client, 'NULL' ) as MeasuredDate
}

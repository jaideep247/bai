// Artifact: zi_cd_hckmetriccube.ddls.asddls
// Purpose: Analytical cube of metric history for trend charts (volume per source/LOB
//          per day, job duration, error rates). Verify annotations on target release.
// Modification log: 2026-11-05 | Initial version (ops suite consolidation).
//                   2026-11-06 | Measures by metric semantics: volume SUM, level MAX / AVG, rate weighted (audit A88).
//                   2026-11-10 | Company code of the metric (company-code isolation).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Health check metrics - cube'
@Metadata.ignorePropagatedAnnotations: true
@Analytics.dataCategory: #CUBE
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #L, dataClass: #MIXED }
@VDM.viewType: #COMPOSITE
define view entity ZI_CD_HckMetricCube
  as select from ZI_CD_HckMetric
  association [1..1] to ZI_CD_HckCheck as _Check on $projection.CheckId = _Check.CheckId
{
  key RunId,
      @ObjectModel.foreignKey.association: '_Check'
  key CheckId,
  key Metric,
  key Dimension1,
  key Dimension2,
      PaymentEngineArea,
      CompanyCode,
      MeasuredDate,
      _Check.Category                                     as Category,
      MetricKind,
      // A88: a measure only aggregates the metrics it is meaningful for - volumes add up,
      // levels (durations, ages) take MAX or AVG, rates are weighted by their denominator.
      // Adding rates or durations (the former MetricValue SUM) is not offered any more.
      @Aggregation.default: #SUM
      case MetricKind when 'V' then MetricValue else cast( 0 as abap.dec( 31, 4 ) ) end as VolumeValue,
      @Aggregation.default: #MAX
      case MetricKind when 'L' then MetricValue else cast( 0 as abap.dec( 31, 4 ) ) end as LevelMax,
      @Aggregation.default: #SUM
      case MetricKind when 'L' then MetricValue else cast( 0 as abap.dec( 31, 4 ) ) end as LevelSum,
      @Aggregation.default: #SUM
      cast( case MetricKind when 'L' then 1 else 0 end as abap.int4 ) as LevelSamples,
      // VERIFY-ADT: DEC -> DECFLOAT34 cast and product (avoids DEC(31) overflow of value * weight)
      @Aggregation.default: #SUM
      case MetricKind when 'R'
           then cast( MetricValue as abap.decfloat34 ) * cast( Weight as abap.decfloat34 )
           else cast( 0 as abap.decfloat34 ) end          as RateWeightedSum,
      @Aggregation.default: #SUM
      case MetricKind when 'R' then cast( Weight as abap.decfloat34 )
           else cast( 0 as abap.decfloat34 ) end          as RateWeight,
      // any kind: highest / lowest single measurement and number of measurements
      @Aggregation.default: #MAX
      MetricValue                                         as MaxValue,
      @Aggregation.default: #MIN
      MetricValue                                         as MinValue,
      @Aggregation.default: #SUM
      cast( 1 as abap.int4 )                              as SampleCount,
      _Check
}

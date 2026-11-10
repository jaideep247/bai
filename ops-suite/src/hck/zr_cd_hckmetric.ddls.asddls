// Artifact: zr_cd_hckmetric.ddls.asddls
// Purpose: Metric history of the last 31 days (health check dashboard drill-down: check -> metric
//          trend): one row per run, check, metric, DIM1 and DIM2 series with value, kind, run date
//          and the check's text and category. Trend chart: value per day, one line per DIM2 series.
//          Drill-down: metric -> findings of the check. Read-only.
// Modification log: 2026-11-06 | Initial version (health check dashboard).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'HCK health check dashboard - metric'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #L, dataClass: #MIXED }
define root view entity ZR_CD_HckMetric
  as select from    ZI_CD_HckMetricBase as Met
    left outer join zcd_hck_def         as Def on Def.check_id = Met.CheckId
  association [0..*] to ZR_CD_HckFind as _Findings on  $projection.CheckId = _Findings.CheckId
                                                   and _Findings.IsOpen    = 'X'
{
  key Met.RunId,
  key Met.CheckId,
  key Met.Metric,
  key Met.Dimension1,
  key Met.Dimension2,
      cast( 'CD_HCK' as abap.char( 16 ) )                       as PaymentEngineArea,
      Def.description                                       as CheckText,
      Def.category                                          as Category,
      Met.MetricKind,
      Met.MetricValue,
      Met.Weight,
      Met.MeasuredAt,
      Met.MeasuredDate,
      cast( 1 as abap.int4 )                                as SampleCount,
      _Findings
}

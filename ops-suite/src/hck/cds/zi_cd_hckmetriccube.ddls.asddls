// Artifact: zi_cd_hckmetriccube.ddls.asddls
// Purpose: Analytical cube of metric history for trend charts (volume per source/LOB
//          per day, job duration, error rates). Verify annotations on target release.
// Modification log: 2026-11-05 | Initial version (ops suite consolidation).
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
      Module,
      MeasuredDate,
      _Check.Category                                     as Category,
      // SUM is right for volumes (counts); for durations / rates use MaxValue or divide by SampleCount
      @Aggregation.default: #SUM
      MetricValue,
      @Aggregation.default: #MAX
      MetricValue                                         as MaxValue,
      @Aggregation.default: #MIN
      MetricValue                                         as MinValue,
      @Aggregation.default: #SUM
      cast( 1 as abap.int4 )                              as SampleCount,
      _Check
}

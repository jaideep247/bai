// Artifact: zi_cd_hckmetric.ddls.asddls
// Purpose: Basic interface view over ZCD_HCK_METRIC (metric history: volumes,
//          durations, error rates) for trends. Verify annotations on target release.
// Modification log: 2026-11-05 | Initial version (ops suite consolidation).
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
      // constant module for the DCL (same authorization object as findings)
      cast( 'HCK' as abap.char(4) )                       as Module,
      value                                               as MetricValue,
      measured_at                                         as MeasuredAt,
      // verify on target release: TIMESTAMPL -> TIMESTAMP cast, UTC calendar day
      tstmp_to_dats( cast( measured_at as timestamp ), 'UTC', $session.client, 'NULL' ) as MeasuredDate
}

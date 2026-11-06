// Artifact: zi_cd_hckrunmetric.ddls.asddls
// Purpose: Number of metric rows each check wrote in each morning report run (last 31 days):
//          a check with metric rows and no B / E / W finding ran GREEN. Read-only.
// Modification log: 2026-11-06 | Initial version (health check dashboard).
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'HCK metric rows per run and check'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #M, dataClass: #TRANSACTIONAL }
@VDM.viewType: #COMPOSITE
define view entity ZI_CD_HckRunMetric
  as select from ZI_CD_HckMetricBase
{
  key RunId,
  key CheckId,
      cast( count( * ) as abap.int4 )                       as MetricCount
}
group by
  RunId,
  CheckId

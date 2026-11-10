// Artifact: zi_cd_hckmetricbase.ddls.asddls
// Purpose: Basic view of the metric history (ZCD_HCK_METRIC) measured in the last 31 days
//          (bounded read, index TIM on MEASURED_AT) for the health check dashboard: run, check,
//          metric, DIM1 / DIM2 series, value, kind (A88: V volume, L level, R rate; rows written
//          before the field existed count as volumes), weight, UTC measurement day. The cds/
//          analytics view ZI_CD_HckMetric holds the same rows for Analysis for Office; this one
//          lives in src/hck so that the abapGit pull never depends on cds/ objects. Read-only.
// Modification log: 2026-11-06 | Initial version (health check dashboard).
//                   2026-11-10 | Company code of the metric (ZCD_HCK_METRIC-BUKRS, company-code isolation).
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'HCK metric history of 31 days (basic)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #L, dataClass: #TRANSACTIONAL }
@VDM.viewType: #BASIC
define view entity ZI_CD_HckMetricBase
  as select from zcd_hck_metric
{
  key run_id                                                as RunId,
  key check_id                                              as CheckId,
  key metric                                                as Metric,
  key dim1                                                  as Dimension1,
  key dim2                                                  as Dimension2,
      value                                                 as MetricValue,
      cast( case kind when 'L' then 'L' when 'R' then 'R' else 'V' end as abap.char( 1 ) ) as MetricKind,
      weight                                                as Weight,
      measured_at                                           as MeasuredAt,
      // Company code the metric is about (blank = not company-specific; company-code isolation)
      bukrs                                                 as CompanyCode,
      tstmp_to_dats( cast( measured_at as timestamp ), 'UTC', $session.client, 'NULL' ) as MeasuredDate
}
where tstmp_to_dats( cast( measured_at as timestamp ), 'UTC', $session.client, 'NULL' )
      >= dats_add_days( $session.system_date, -31, 'INITIAL' )

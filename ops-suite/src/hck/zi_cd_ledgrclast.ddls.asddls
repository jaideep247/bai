// Artifact: zi_cd_ledgrclast.ddls.asddls
// Purpose: Ledger model (group reconciliation, build C): the LATEST measurement of every group-day of the three-way
//          reconciliation A_RECON_3WAY - per check, group (DIM1 BUKRS/HKONT/WAERS) and ISO day (DIM2) the newest
//          MEASURED_AT of its leg metrics RC_BANK / RC_GL / RC_FICA (the evidence every group-day with data records,
//          HCK_MORNING_REPORT.md section 7z). A newer run that measured the same group-day replaces the older one, as in
//          ZI_CD_OpsVarBank. Results only: no bank, G/L or payment engine line is read. Read-only.
// Modification log: 2026-11-11 | Initial version (ledger drill-down and group reconciliation, build C).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Ledger reconciliation - latest measurement'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #M, dataClass: #TRANSACTIONAL }
define view entity ZI_CD_LedgRcLast
  as select from zcd_hck_metric as Metric
{
  key Metric.check_id                                       as CheckId,
  key Metric.dim1                                           as ReconGroup,
  key Metric.dim2                                           as ReconDay,
      max( Metric.measured_at )                             as MeasuredAt
}
where
     Metric.metric = 'RC_BANK'
  or Metric.metric = 'RC_GL'
  or Metric.metric = 'RC_FICA'
group by
  Metric.check_id,
  Metric.dim1,
  Metric.dim2

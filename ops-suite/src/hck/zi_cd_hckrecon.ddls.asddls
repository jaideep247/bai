// Artifact: zi_cd_hckrecon.ddls.asddls
// Purpose: Results of the three-way reconciliation (check A_RECON_3WAY) as the morning report
//          stored them: the metrics RC_* of ZCD_HCK_METRIC - difference per group and day
//          (RC_DIFF_BANK_GL, RC_DIFF_GL_FICA, RC_UNEXPLAINED), group days per status (RC_DAYS) and
//          per variance bucket (RC_BUCKET), Stripe group differences (RC_STRIPE_DIFF), unmatched
//          ACH groups (RC_ACH_OPEN), breaks of the run (RC_BREAKS). The group key DIM1
//          BUKRS/HKONT/WAERS is split by position (widths ZIF_CD_HCK_RECON_TYPES=>GC_GROUP_WIDTH,
//          prefix GC_METRIC_PREFIX; portable check cds_abap_parity); DIM2 is the ISO day, the
//          status, the bucket or the descriptor. No bank, G/L or payment engine line is stored or
//          read here (results only). Amounts are in the group currency - slice by Currency.
//          Read-only.
// Modification log: 2026-11-07 | Initial version (three-way reconciliation check A_RECON_3WAY).
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'HCK three-way reconciliation results'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #L, dataClass: #TRANSACTIONAL }
@VDM.viewType: #BASIC
define view entity ZI_CD_HckRecon
  as select from zcd_hck_metric as Metric
{
  key Metric.run_id                                         as RunId,
  key Metric.check_id                                       as CheckId,
  key Metric.metric                                         as Metric,
  key Metric.dim1                                           as ReconGroup,
  key Metric.dim2                                           as Detail,
      cast( substring( Metric.dim1, 1, 4 ) as abap.char( 4 ) )   as CompanyCode,
      cast( substring( Metric.dim1, 6, 10 ) as abap.char( 10 ) ) as GlAccount,
      cast( substring( Metric.dim1, 17, 5 ) as abap.char( 5 ) )  as Currency,
      // ISO day of the per-day metrics (YYYY-MM-DD in DIM2), else initial
      cast( case when substring( Metric.dim2, 5, 1 ) = '-' and substring( Metric.dim2, 8, 1 ) = '-'
                 then concat( concat( substring( Metric.dim2, 1, 4 ), substring( Metric.dim2, 6, 2 ) ),
                              substring( Metric.dim2, 9, 2 ) )
                 else '00000000' end as abap.dats )      as PostingDate,
      Metric.value                                          as MetricValue,
      Metric.measured_at                                    as MeasuredAt
}
where left( Metric.metric, 3 ) = 'RC_'

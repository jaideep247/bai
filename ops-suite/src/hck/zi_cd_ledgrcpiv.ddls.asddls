// Artifact: zi_cd_ledgrcpiv.ddls.asddls
// Purpose: Ledger model (group reconciliation, build C): the stored legs of the latest measurement of a group-day of
//          A_RECON_3WAY side by side - bank leg RC_BANK, G/L leg RC_GL (lines of the payment engine G/L transfer on the
//          clearing account), payment engine leg RC_FICA (DFKKSUMC), differences RC_DIFF_BANK_GL / RC_DIFF_GL_FICA and the
//          tolerance used (RC_TOLERANCE_SET or _PARAM) - one row per run, check, group and day (MAX of a CASE per
//          metric: each metric is stored once per run and group-day). Reused, never recomputed. Read-only.
// Modification log: 2026-11-11 | Initial version (ledger drill-down and group reconciliation, build C).
// VERIFY-ADT: MAX over a CASE of DEC 31,4 values in a view entity with an inner join on a time stamp (7.58).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Ledger reconciliation - stored legs'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #M, dataClass: #TRANSACTIONAL }
define view entity ZI_CD_LedgRcPiv
  as select from zcd_hck_metric   as Metric
    inner join   ZI_CD_LedgRcLast as Last on  Last.CheckId    = Metric.check_id
                                          and Last.ReconGroup = Metric.dim1
                                          and Last.ReconDay   = Metric.dim2
                                          and Last.MeasuredAt = Metric.measured_at
{
  key Metric.run_id                                         as RunId,
  key Metric.check_id                                       as CheckId,
  key Metric.dim1                                           as ReconGroup,
  key Metric.dim2                                           as ReconDay,
      max( Metric.measured_at )                             as MeasuredAt,
      // object keys of the check's findings of this group-day (<check>/<group>/<day>/BANK and .../FICA, as
      // ZIF_CD_HCK_RECON_TYPES and ZI_CD_OpsVarBank)
      cast( concat( concat( concat( concat( concat( concat( Metric.check_id, '/' ), Metric.dim1 ), '/' ),
                                    Metric.dim2 ), '/' ), 'BANK' ) as abap.char( 70 ) ) as BankFindingKey,
      cast( concat( concat( concat( concat( concat( concat( Metric.check_id, '/' ), Metric.dim1 ), '/' ),
                                    Metric.dim2 ), '/' ), 'FICA' ) as abap.char( 70 ) ) as FicaFindingKey,
      max( case when Metric.metric = 'RC_BANK' then Metric.value end )         as BankAmount,
      max( case when Metric.metric = 'RC_GL' then Metric.value end )           as GlAmount,
      max( case when Metric.metric = 'RC_FICA' then Metric.value end )         as SubledgerAmount,
      max( case when Metric.metric = 'RC_DIFF_BANK_GL' then Metric.value end ) as BankGlDifference,
      max( case when Metric.metric = 'RC_DIFF_GL_FICA' then Metric.value end ) as GlSubledgerDifference,
      max( case when Metric.metric = 'RC_TOLERANCE_SET' or Metric.metric = 'RC_TOLERANCE_PARAM'
                then Metric.value end )                     as Tolerance
}
group by
  Metric.run_id,
  Metric.check_id,
  Metric.dim1,
  Metric.dim2

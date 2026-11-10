// Artifact: zi_cd_opsvarbank.ddls.asddls
// Purpose: Variances of the bank <-> G/L leg of the three-way reconciliation (A_RECON_3WAY), from the metrics
//          the morning report already stored (ZCD_HCK_METRIC, no new storage): per group (DIM1
//          BUKRS/HKONT/WAERS) and day (DIM2, ISO) the LATEST measurement of RC_DIFF_BANK_GL (a newer run that
//          measured the same group-day replaces it - anti-join, index HST), with the tolerance the check used
//          (RC_TOLERANCE_SET / _PARAM of the same run), expected = bank leg RC_BANK, SAP actual = G/L leg RC_GL;
//          only a difference beyond the tolerance is a variance. FindingKey = the object key of the check's
//          finding of that group-day and leg (<check>/<group>/<day>/BANK, ZIF_CD_HCK_RECON_TYPES). Read-only.
// Modification log: 2026-11-10 | Initial version (control center: open variances).
// VERIFY-ADT: abs( ) on DEC 31,4 and concat of CHAR fields (trailing blanks dropped as in the ABAP string
//             template of the finding key) in a CDS view entity (7.58).
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Reconciliation variance - bank vs G/L'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #M, dataClass: #TRANSACTIONAL }
define view entity ZI_CD_OpsVarBank
  as select from    zcd_hck_metric as Diff
    left outer join zcd_hck_metric as Newer on  Newer.check_id    = Diff.check_id
                                            and Newer.metric      = Diff.metric
                                            and Newer.dim1        = Diff.dim1
                                            and Newer.dim2        = Diff.dim2
                                            and Newer.measured_at > Diff.measured_at
    inner join      zcd_hck_metric as Tol   on  Tol.run_id   = Diff.run_id
                                            and Tol.check_id = Diff.check_id
                                            and Tol.dim1     = Diff.dim1
                                            and Tol.dim2     = Diff.dim2
                                            and (    Tol.metric = 'RC_TOLERANCE_SET'
                                                  or Tol.metric = 'RC_TOLERANCE_PARAM' )
    left outer join zcd_hck_metric as Exp   on  Exp.run_id   = Diff.run_id
                                            and Exp.check_id = Diff.check_id
                                            and Exp.metric   = 'RC_BANK'
                                            and Exp.dim1     = Diff.dim1
                                            and Exp.dim2     = Diff.dim2
    left outer join zcd_hck_metric as Act   on  Act.run_id   = Diff.run_id
                                            and Act.check_id = Diff.check_id
                                            and Act.metric   = 'RC_GL'
                                            and Act.dim1     = Diff.dim1
                                            and Act.dim2     = Diff.dim2
{
  key Diff.check_id                                         as CheckId,
  key Diff.dim1                                             as ReconGroup,
  key Diff.dim2                                             as ReconDay,
  key cast( 'BANK' as abap.char( 4 ) )                      as Leg,
      // the reconciled day (ISO YYYY-MM-DD in DIM2) as a date - the business date of the variance
      cast( concat( concat( substring( Diff.dim2, 1, 4 ), substring( Diff.dim2, 6, 2 ) ),
                    substring( Diff.dim2, 9, 2 ) ) as abap.dats ) as ReconDate,
      Diff.run_id                                           as RunId,
      Diff.measured_at                                      as MeasuredAt,
      Diff.value                                            as Difference,
      Tol.value                                             as Tolerance,
      Exp.value                                             as ExpectedAmount,
      Act.value                                             as ActualAmount,
      cast( concat( concat( concat( concat( concat( concat( Diff.check_id, '/' ), Diff.dim1 ), '/' ),
                                    Diff.dim2 ), '/' ), 'BANK' ) as abap.char( 70 ) ) as FindingKey
}
where
      Diff.metric      =  'RC_DIFF_BANK_GL'
  and Newer.run_id     is null
  and abs( Diff.value ) > Tol.value

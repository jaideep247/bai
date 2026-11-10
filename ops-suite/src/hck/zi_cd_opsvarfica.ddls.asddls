// Artifact: zi_cd_opsvarfica.ddls.asddls
// Purpose: Variances of the G/L <-> payment engine leg of the three-way reconciliation (A_RECON_3WAY), from the
//          stored metrics (ZCD_HCK_METRIC, no new storage): the latest RC_DIFF_GL_FICA of a group-day beyond the
//          tolerance of its run, expected = G/L leg RC_GL, SAP actual = payment engine control total RC_FICA;
//          FindingKey <check>/<group>/<day>/FICA. Same rules as ZI_CD_OpsVarBank. Read-only.
// Modification log: 2026-11-10 | Initial version (control center: open variances).
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Reconciliation variance - G/L vs subledger'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #M, dataClass: #TRANSACTIONAL }
define view entity ZI_CD_OpsVarFica
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
                                            and Exp.metric   = 'RC_GL'
                                            and Exp.dim1     = Diff.dim1
                                            and Exp.dim2     = Diff.dim2
    left outer join zcd_hck_metric as Act   on  Act.run_id   = Diff.run_id
                                            and Act.check_id = Diff.check_id
                                            and Act.metric   = 'RC_FICA'
                                            and Act.dim1     = Diff.dim1
                                            and Act.dim2     = Diff.dim2
{
  key Diff.check_id                                         as CheckId,
  key Diff.dim1                                             as ReconGroup,
  key Diff.dim2                                             as ReconDay,
  key cast( 'FICA' as abap.char( 4 ) )                      as Leg,
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
                                    Diff.dim2 ), '/' ), 'FICA' ) as abap.char( 70 ) ) as FindingKey
}
where
      Diff.metric      =  'RC_DIFF_GL_FICA'
  and Newer.run_id     is null
  and abs( Diff.value ) > Tol.value

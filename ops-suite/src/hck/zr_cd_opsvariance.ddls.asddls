// Artifact: zr_cd_opsvariance.ddls.asddls
// Purpose: "Open variances" card and list of the overview page (reconciliation): per group-day and leg of the
//          three-way reconciliation whose latest difference is beyond the tolerance (ZI_CD_OpsVarU) - business
//          date = the reconciled day, company code / G/L account / currency of the group, expected, SAP actual,
//          variance = actual minus expected, tolerance, and the DISPOSITION from the exception workflow (no
//          separate variance table): the finding of that group-day and leg in the measuring run (break =
//          owned exception) - its reason code when classified in the exceptions app (TIMING, INVESTIGATING,
//          ... parameter EXC_REASON_CODES), TIMING when the check itself classified the day as timing
//          (RECON_TIMING), RESOLVED / WAIVED when closed, OPEN when open, UNCLASSIFIED without a finding.
//          Unresolved = OPEN, UNCLASSIFIED or a reason code other than TIMING. Results only - no bank, G/L or
//          payment engine line is read. Read-only.
// Modification log: 2026-11-10 | Initial version (control center: open variances).
// VERIFY-ADT: DEC 31,4 arithmetic (actual minus expected) and casts of the ISO day in a view entity (7.58).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Production support - reconciliation variances'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #M, dataClass: #TRANSACTIONAL }
define root view entity ZR_CD_OpsVariance
  as select from    ZI_CD_OpsVarU   as Var
    left outer join zca_ops_finding as Fnd on  Fnd.run_id     = Var.RunId
                                           and Fnd.area       = 'CD_HCK'
                                           and Fnd.object_key = Var.FindingKey
    left outer join ZI_CA_OpsBusDay as Day on  Day.BusinessDate = Var.ReconDate
{
  key Var.CheckId,
  key Var.ReconGroup,
  key Var.ReconDay,
  key Var.Leg,
      Var.ReconDate                                         as BusinessDate,
      cast( 'CD_HCK' as abap.char( 16 ) )                   as PaymentEngineArea,
      cast( substring( Var.ReconGroup, 1, 4 ) as abap.char( 4 ) )   as CompanyCode,
      cast( substring( Var.ReconGroup, 6, 10 ) as abap.char( 10 ) ) as GlAccount,
      cast( substring( Var.ReconGroup, 17, 5 ) as abap.char( 5 ) )  as Currency,
      Var.RunId,
      Var.MeasuredAt,
      Var.ExpectedAmount,
      Var.ActualAmount,
      cast( Var.ActualAmount - Var.ExpectedAmount as abap.dec( 31, 4 ) ) as VarianceAmount,
      Var.Tolerance,
      Fnd.check_code                                        as FindingCode,
      Fnd.disposition                                       as ExceptionDisposition,
      Fnd.reason_code                                       as ReasonCode,
      Fnd.owner                                             as ExceptionOwner,
      cast( case when Fnd.reason_code is not null and Fnd.reason_code <> ' ' then Fnd.reason_code
                 when Fnd.check_code = 'RECON_TIMING' then 'TIMING'
                 when Fnd.disposition = 'R' then 'RESOLVED'
                 when Fnd.disposition = 'W' then 'WAIVED'
                 when Fnd.run_id is null then 'UNCLASSIFIED'
                 else 'OPEN' end as abap.char( 12 ) )       as VarianceDisposition,
      cast( case when Fnd.reason_code = 'TIMING' then 'X'
                 when ( Fnd.reason_code is null or Fnd.reason_code = ' ' ) and Fnd.check_code = 'RECON_TIMING' then 'X'
                 else ' ' end as abap_boolean )             as IsTiming,
      cast( case when Fnd.reason_code = 'TIMING' then ' '
                 when ( Fnd.reason_code is null or Fnd.reason_code = ' ' ) and Fnd.check_code = 'RECON_TIMING' then ' '
                 when ( Fnd.reason_code is null or Fnd.reason_code = ' ' )
                  and ( Fnd.disposition = 'R' or Fnd.disposition = 'W' ) then ' '
                 else 'X' end as abap_boolean )             as IsUnresolved,
      cast( case when Fnd.reason_code = 'TIMING' then 2
                 when ( Fnd.reason_code is null or Fnd.reason_code = ' ' ) and Fnd.check_code = 'RECON_TIMING' then 2
                 when ( Fnd.reason_code is null or Fnd.reason_code = ' ' )
                  and ( Fnd.disposition = 'R' or Fnd.disposition = 'W' ) then 3
                 else 1 end as abap.int1 )                  as VarianceCriticality,
      cast( case when Day.IsCurrentDay = 'X' then 'X' else ' ' end as abap_boolean ) as IsCurrentDay,
      cast( 1 as abap.int4 )                                as VarianceCount
}

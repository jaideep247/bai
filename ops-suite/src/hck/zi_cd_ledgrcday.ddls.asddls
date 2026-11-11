// Artifact: zi_cd_ledgrcday.ddls.asddls
// Purpose: Ledger model (group reconciliation, build C): the stored result of a group-day of the three-way
//          reconciliation A_RECON_3WAY as the payment model's section recon_result needs it (mapping
//          config/payment_model/mapping.json): business date (the ISO day of DIM2), company code / clearing account /
//          currency of the group (DIM1 split by position, widths ZIF_CD_HCK_RECON_TYPES=>GC_GROUP_WIDTH as
//          ZI_CD_HckRecon), the stored legs and differences (ZI_CD_LedgRcPiv) and the verdict from the check's findings
//          of that run: the finding of the bank leg (<check>/<group>/<day>/BANK) and of the subledger leg (.../FICA) -
//          BREAK (RECON_BREAK), SUBLEDGER_BREAK (RECON_SUBLEDGER_BREAK), VARIANCE (RECON_VARIANCE: cheque / unmapped /
//          other bucket), TIMING (RECON_TIMING: timing / cut-off / redeposit bucket), else BALANCED. Bucket = the check
//          code of the leg's finding; the bucket names of the day (TIMING, CUTOFF, REDEPOSIT, CHEQUE, UNMAPPED, OTHER)
//          are in the finding's message and details - the exceptions app shows them. Reused, never recomputed. Read-only.
// Modification log: 2026-11-11 | Initial version (ledger drill-down and group reconciliation, build C).
// VERIFY-ADT: concat of CHAR fields for the finding key (as ZI_CD_OpsVarBank), ISO day cast (7.58).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Ledger reconciliation - stored result per day'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #M, dataClass: #TRANSACTIONAL }
define view entity ZI_CD_LedgRcDay
  as select from    ZI_CD_LedgRcPiv as Piv
    left outer join zca_ops_finding as BankFnd on  BankFnd.run_id     = Piv.RunId
                                               and BankFnd.area       = 'CD_HCK'
                                               and BankFnd.object_key = Piv.BankFindingKey
    left outer join zca_ops_finding as FicaFnd on  FicaFnd.run_id     = Piv.RunId
                                               and FicaFnd.area       = 'CD_HCK'
                                               and FicaFnd.object_key = Piv.FicaFindingKey
{
  key cast( concat( concat( substring( Piv.ReconDay, 1, 4 ), substring( Piv.ReconDay, 6, 2 ) ),
                    substring( Piv.ReconDay, 9, 2 ) ) as abap.dats ) as BusinessDate,
  key cast( substring( Piv.ReconGroup, 1, 4 ) as abap.char( 4 ) )   as CompanyCode,
  key cast( substring( Piv.ReconGroup, 6, 10 ) as abap.char( 10 ) ) as GlAccount,
  key cast( substring( Piv.ReconGroup, 17, 5 ) as abap.cuky )       as Currency,
      Piv.CheckId,
      Piv.RunId,
      Piv.MeasuredAt,
      Piv.BankAmount,
      Piv.GlAmount,
      Piv.SubledgerAmount,
      Piv.BankGlDifference,
      Piv.GlSubledgerDifference,
      Piv.Tolerance,
      cast( case when BankFnd.check_code = 'RECON_BREAK' then 'BREAK'
                 when FicaFnd.check_code = 'RECON_SUBLEDGER_BREAK' then 'SUBLEDGER_BREAK'
                 when BankFnd.check_code = 'RECON_VARIANCE' then 'VARIANCE'
                 when BankFnd.check_code = 'RECON_TIMING' or FicaFnd.check_code = 'RECON_TIMING' then 'TIMING'
                 else 'BALANCED' end as abap.char( 16 ) )   as ResultStatus,
      cast( coalesce( BankFnd.check_code, FicaFnd.check_code ) as abap.char( 30 ) ) as Bucket
}

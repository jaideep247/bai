// Artifact: zr_{{p}}_ledgrecon.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Ledger model of the {{CONSUMER}} - group reconciliation (entity LedgerReconciliation): per business date x
//          company code x reconciled G/L account x currency the subledger leg (summary records), the journal leg
//          (transfer part of the subledger batch keys + other postings) and, where the consumer delivers them, the
//          bank leg with its "reset / reversal" bucket and the STORED results of the consumer's reconciliation check
//          (legs, differences, tolerance, status and bucket as measured - reused, never recomputed here). The live
//          journal / subledger totals add the drill-down and one piece of evidence the stored result cannot have: a
//          journal or subledger change after the measurement (IsChangedSinceMeasured). Every row shows its counts and
//          next levels: batch keys of the day (_Batches), journal lines (_Journal, paged), bank lines (_BankLines).
//          Amounts DEC with the currency beside them, never added across currencies. Read-only.
// Modification log: {{SINCE}} | Generated from the product template (ledger model).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Ledger model - group reconciliation'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define root view entity ZR_{{P}}_LedgRecon
  as select from    ZI_{{P}}_LedgRcKey   as Grp
    inner join      ZI_{{P}}_LedgAcct    as Acc on  Acc.CompanyCode = Grp.CompanyCode
                                                and Acc.GlAccount   = Grp.GlAccount
                                                and Acc.Currency    = Grp.Currency
    left outer join ZI_{{P}}_LedgAcctDay as Jrn on  Jrn.CompanyCode = Grp.CompanyCode
                                                and Jrn.GlAccount   = Grp.GlAccount
                                                and Jrn.Currency    = Grp.Currency
                                                and Jrn.PostingDate = Grp.BusinessDate
    left outer join ZI_{{P}}_LedgSubDay  as Sub on  Sub.CompanyCode = Grp.CompanyCode
                                                and Sub.GlAccount   = Grp.GlAccount
                                                and Sub.Currency    = Grp.Currency
                                                and Sub.PostingDate = Grp.BusinessDate
#if RESULT
    left outer join ZI_{{P}}_LedgRcRes   as Res on  Res.CompanyCode  = Grp.CompanyCode
                                                and Res.GlAccount    = Grp.GlAccount
                                                and Res.Currency     = Grp.Currency
                                                and Res.BusinessDate = Grp.BusinessDate
#endif
#if BANK
    left outer join ZI_{{P}}_LedgBankDay as Bnk on  Bnk.CompanyCode = Grp.CompanyCode
                                                and Bnk.GlAccount   = Grp.GlAccount
                                                and Bnk.Currency    = Grp.Currency
                                                and Bnk.BookingDate = Grp.BusinessDate
#endif
  association [0..*] to ZR_{{P}}_LedgBatch  as _Batches   on  $projection.CompanyCode  = _Batches.CompanyCode
                                                         and $projection.GlAccount    = _Batches.GlAccount
                                                         and $projection.Currency     = _Batches.Currency
                                                         and $projection.BusinessDate = _Batches.PostingDate
  association [0..*] to ZR_{{P}}_LedgJrnl   as _Journal   on  $projection.CompanyCode  = _Journal.CompanyCode
                                                         and $projection.GlAccount    = _Journal.GlAccount
                                                         and $projection.Currency     = _Journal.TransactionCurrency
                                                         and $projection.BusinessDate = _Journal.PostingDate
#if BANK
  association [0..*] to ZR_{{P}}_LedgBankLn as _BankLines on  $projection.CompanyCode  = _BankLines.CompanyCode
                                                         and $projection.GlAccount    = _BankLines.GlAccount
                                                         and $projection.Currency     = _BankLines.Currency
                                                         and $projection.BusinessDate = _BankLines.BookingDate
#endif
{
  key Grp.BusinessDate,
  key Grp.CompanyCode,
  key Grp.GlAccount,
  key Grp.Currency,
      _Batches,
      _Journal,
#if BANK
      _BankLines,
#endif
      cast( '{{AREA}}' as abap.char( 16 ) )                 as OpsArea,
      Acc.AccountKind,
      Acc.Description                                       as AccountDescription,
      cast( coalesce( Sub.SubledgerAmount, 0 ) as abap.dec( 23, 2 ) ) as SubledgerAmount,
      coalesce( Sub.BatchCount, 0 )                         as BatchCount,
      cast( coalesce( Jrn.TransferAmount, 0 ) as abap.dec( 23, 2 ) ) as JournalTransferAmount,
      cast( coalesce( Jrn.JournalAmount, 0 ) - coalesce( Jrn.TransferAmount, 0 ) as abap.dec( 23, 2 ) ) as JournalOtherAmount,
      cast( coalesce( Jrn.JournalAmount, 0 ) as abap.dec( 23, 2 ) ) as JournalAmount,
      coalesce( Jrn.JournalLineCount, 0 )                   as JournalLineCount,
      // G/L transfer vs subledger, live (the subledger leg of the drill-down)
      cast( coalesce( Jrn.TransferAmount, 0 ) - coalesce( Sub.SubledgerAmount, 0 ) as abap.dec( 23, 2 ) ) as LiveDifference,
#if BANK
      cast( coalesce( Bnk.BankAmount, 0 ) as abap.dec( 23, 2 ) ) as BankAmount,
      coalesce( Bnk.BankLineCount, 0 )                      as BankLineCount,
      cast( coalesce( Bnk.ChangedAmount, 0 ) as abap.dec( 23, 2 ) ) as ResetReversalAmount,
      coalesce( Bnk.ChangedLineCount, 0 )                   as ResetReversalLineCount,
#endif
#if RESULT
      Res.BankAmount                                        as StoredBankAmount,
      Res.GlAmount                                          as StoredGlAmount,
      Res.SubledgerAmount                                   as StoredSubledgerAmount,
      Res.BankGlDifference                                  as StoredBankGlDifference,
      Res.GlSubledgerDifference                             as StoredGlSubDifference,
      Res.Tolerance,
      cast( coalesce( Res.ResultStatus, 'NOT_MEASURED' ) as abap.char( 16 ) ) as ResultStatus,
      Res.Bucket,
      Res.MeasuredAt,
      cast( case when Res.GlAmount is null then ' '
                 when cast( Res.GlAmount as abap.dec( 23, 2 ) ) <> cast( coalesce( Jrn.TransferAmount, 0 ) as abap.dec( 23, 2 ) )
                 then 'X' else ' ' end as abap_boolean )    as IsChangedSinceMeasured,
      cast( case when Res.ResultStatus = 'BALANCED' then 3
                 when Res.ResultStatus = 'TIMING' or Res.ResultStatus = 'VARIANCE' then 2
                 when Res.ResultStatus is null and coalesce( Jrn.TransferAmount, 0 ) = coalesce( Sub.SubledgerAmount, 0 ) then 3
                 when Res.ResultStatus is null then 2
                 else 1 end as abap.int1 )                  as StatusCriticality,
#else
      cast( case when coalesce( Jrn.TransferAmount, 0 ) = coalesce( Sub.SubledgerAmount, 0 ) then 3
                 else 2 end as abap.int1 )                  as StatusCriticality,
#endif
      cast( 1 as abap.int4 )                                as GroupDayCount
}

// Artifact: zc_{{p}}_ledgrecon.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Ledger model of the {{CONSUMER}} - group reconciliation (entity LedgerReconciliation of {{SERVICE}}): list
//          per business date (mandatory filter) x company code x G/L account x currency with the legs, differences,
//          status and bucket, object page with batch keys, journal lines and bank lines. Read access: DCL ZC_{{P}}_PAYM.
// Modification log: {{SINCE}} | Generated from the product template (ledger model).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Ledger model - group reconciliation'
@Metadata.allowExtensions: true
define root view entity ZC_{{P}}_LedgRecon
  provider contract transactional_query
  as projection on ZR_{{P}}_LedgRecon
{
  key BusinessDate,
  key CompanyCode,
  key GlAccount,
  key Currency,
      _Batches   : redirected to ZC_{{P}}_LedgBatch,
      _Journal   : redirected to ZC_{{P}}_LedgJrnl,
#if BANK
      _BankLines : redirected to ZC_{{P}}_LedgBankLn,
#endif
      OpsArea,
      AccountKind,
      AccountDescription,
      SubledgerAmount,
      BatchCount,
      JournalTransferAmount,
      JournalOtherAmount,
      JournalAmount,
      JournalLineCount,
      LiveDifference,
#if BANK
      BankAmount,
      BankLineCount,
      ResetReversalAmount,
      ResetReversalLineCount,
#endif
#if RESULT
      StoredBankAmount,
      StoredGlAmount,
      StoredSubledgerAmount,
      StoredBankGlDifference,
      StoredGlSubDifference,
      Tolerance,
      ResultStatus,
      Bucket,
      MeasuredAt,
      IsChangedSinceMeasured,
#endif
      StatusCriticality,
      @Aggregation.default: #SUM
      GroupDayCount
}

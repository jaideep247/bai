// Artifact: zc_cd_ledgrecon.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Ledger model of the ops suite - group reconciliation (entity LedgerReconciliation of ZUI_CD_PAYM): list
//          per business date (mandatory filter) x company code x G/L account x currency with the legs, differences,
//          status and bucket, object page with batch keys, journal lines and bank lines. Read access: DCL ZC_CD_PAYM.
// Modification log: 2026-11-11 | Generated from the product template (ledger model).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Ledger model - group reconciliation'
@Metadata.allowExtensions: true
define root view entity ZC_CD_LedgRecon
  provider contract transactional_query
  as projection on ZR_CD_LedgRecon
{
  key BusinessDate,
  key CompanyCode,
  key GlAccount,
  key Currency,
      _Batches   : redirected to ZC_CD_LedgBatch,
      _Journal   : redirected to ZC_CD_LedgJrnl,
      _BankLines : redirected to ZC_CD_LedgBankLn,
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
      BankAmount,
      BankLineCount,
      ResetReversalAmount,
      ResetReversalLineCount,
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
      StatusCriticality,
      @Aggregation.default: #SUM
      GroupDayCount
}

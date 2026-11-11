// Artifact: zc_cd_ledgbankln.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Ledger model of the ops suite - bank statement line (entity BankStatementLine of ZUI_CD_PAYM): bank
//          lines table of the reconciliation page (paged) and the object page of one line with its G/L clearing line,
//          payment and change timeline. Read access: DCL ZC_CD_PAYM.
// Modification log: 2026-11-11 | Generated from the product template (ledger model).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Ledger model - bank statement line'
@Metadata.allowExtensions: true
define root view entity ZC_CD_LedgBankLn
  provider contract transactional_query
  as projection on ZR_CD_LedgBankLn
{
  key StatementKey,
  key StatementLine,
      _GlLine  : redirected to ZC_CD_LedgJrnl,
      _Payment : redirected to ZC_CD_Payment,
      _Changes : redirected to ZC_CD_PaymChange,
      OpsArea,
      CompanyCode,
      GlAccount,
      Currency,
      BookingDate,
      @Semantics.amount.currencyCode: 'Currency'
      Amount,
      DebitCredit,
      HouseBank,
      HouseBankAccount,
      StatementNumber,
      StatementDate,
      TransactionCode,
      BankReference,
      ReferenceText,
      ValueDate,
      IsPostedArea1,
      IsPostedArea2,
      ClearingDocument,
      ClearingChanged,
      LineCriticality,
      GlFiscalYear,
      GlDocument,
      GlLineItem,
      @Aggregation.default: #SUM
      LineCount
}

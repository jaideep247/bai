// Artifact: zc_{{p}}_ledgbankln.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Ledger model of the {{CONSUMER}} - bank statement line (entity BankStatementLine of {{SERVICE}}): bank
//          lines table of the reconciliation page (paged) and the object page of one line with its G/L clearing line,
//          payment and change timeline. Read access: DCL ZC_{{P}}_PAYM.
// Modification log: {{SINCE}} | Generated from the product template (ledger model).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Ledger model - bank statement line'
@Metadata.allowExtensions: true
define root view entity ZC_{{P}}_LedgBankLn
  provider contract transactional_query
  as projection on ZR_{{P}}_LedgBankLn
{
  key StatementKey,
  key StatementLine,
      _GlLine  : redirected to ZC_{{P}}_LedgJrnl,
      _Payment : redirected to ZC_{{P}}_Payment,
#if CHANGES
      _Changes : redirected to ZC_{{P}}_PaymChange,
#endif
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

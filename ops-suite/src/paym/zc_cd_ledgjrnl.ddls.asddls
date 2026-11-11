// Artifact: zc_cd_ledgjrnl.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Ledger model of the ops suite - journal line (entity JournalLine of ZUI_CD_PAYM): the line tables of the
//          batch key, payment ledger, reconciliation and bank line pages (paged, always reached with keys or with an
//          account and a posting date). Read access: DCL ZC_CD_PAYM (company code of the line).
// Modification log: 2026-11-11 | Generated from the product template (ledger model).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Ledger model - journal line'
@Metadata.allowExtensions: true
define root view entity ZC_CD_LedgJrnl
  provider contract transactional_query
  as projection on ZR_CD_LedgJrnl
{
  key Ledger,
  key CompanyCode,
  key FiscalYear,
  key GlDocument,
  key JournalLine,
      OpsArea,
      GlLineItem,
      FiscalPeriod,
      DocumentType,
      PostingDate,
      DocumentDate,
      EntryDate,
      EntryTime,
      @ObjectModel.text.element: [ 'GlAccountText' ]
      GlAccount,
      @Semantics.text: true
      GlAccountText,
      PostingKey,
      DebitCredit,
      @Semantics.amount.currencyCode: 'TransactionCurrency'
      AmountInTransCurrency,
      TransactionCurrency,
      @Semantics.amount.currencyCode: 'CompanyCodeCurrency'
      AmountInCompanyCurrency,
      CompanyCodeCurrency,
      @Semantics.amount.currencyCode: 'GroupCurrency'
      AmountInGroupCurrency,
      GroupCurrency,
      Assignment,
      ItemText,
      ClearingDocument,
      ClearingDate,
      ProfitCenter,
      Segment,
      BusinessArea,
      CostCenter,
      ReferenceType,
      ReferenceKey,
      ReversalDocument,
      IsReversal,
      IsTransferLine
}

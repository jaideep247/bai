// Artifact: zc_{{p}}_ledgjrnl.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Ledger model of the {{CONSUMER}} - journal line (entity JournalLine of {{SERVICE}}): the line tables of the
//          batch key, payment ledger, reconciliation and bank line pages (paged, always reached with keys or with an
//          account and a posting date). Read access: DCL ZC_{{P}}_PAYM (company code of the line).
// Modification log: {{SINCE}} | Generated from the product template (ledger model).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Ledger model - journal line'
@Metadata.allowExtensions: true
define root view entity ZC_{{P}}_LedgJrnl
  provider contract transactional_query
  as projection on ZR_{{P}}_LedgJrnl
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

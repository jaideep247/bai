// Artifact: zr_cd_ledgjrnl.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Ledger model of the ops suite - journal line (entity JournalLine): the lowest level of every drill-down -
//          batch key -> its G/L documents -> lines (navigation by company code + G/L reference type / key: header
//          index under the released view I_JournalEntry, then the journal by its key), account x posting date of a
//          reconciled account -> lines (paged), bank statement line -> its G/L clearing line (company code, fiscal year,
//          document, line item). IsTransferLine = the line belongs to a G/L document of a subledger batch key
//          (reference type FKKSU). Read-only.
// Modification log: 2026-11-11 | Generated from the product template (ledger model).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Ledger model - journal line'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #XXL, dataClass: #TRANSACTIONAL }
define root view entity ZR_CD_LedgJrnl
  as select from ZI_CD_LedgJrnl as Jrn
{
  key Jrn.Ledger,
  key Jrn.CompanyCode,
  key Jrn.FiscalYear,
  key Jrn.GlDocument,
  key Jrn.JournalLine,
      cast( 'CD_OPS' as abap.char( 16 ) )                 as OpsArea,
      Jrn.GlLineItem,
      Jrn.FiscalPeriod,
      Jrn.DocumentType,
      Jrn.PostingDate,
      Jrn.DocumentDate,
      Jrn.EntryDate,
      Jrn.EntryTime,
      Jrn.GlAccount,
      Jrn.GlAccountText,
      Jrn.PostingKey,
      Jrn.DebitCredit,
      @Semantics.amount.currencyCode: 'TransactionCurrency'
      Jrn.AmountInTransCurrency,
      Jrn.TransactionCurrency,
      @Semantics.amount.currencyCode: 'CompanyCodeCurrency'
      Jrn.AmountInCompanyCurrency,
      Jrn.CompanyCodeCurrency,
      @Semantics.amount.currencyCode: 'GroupCurrency'
      Jrn.AmountInGroupCurrency,
      Jrn.GroupCurrency,
      Jrn.Assignment,
      Jrn.ItemText,
      Jrn.ClearingDocument,
      Jrn.ClearingDate,
      Jrn.ProfitCenter,
      Jrn.Segment,
      Jrn.BusinessArea,
      Jrn.CostCenter,
      Jrn.ReferenceType,
      Jrn.ReferenceKey,
      Jrn.ReversalDocument,
      Jrn.IsReversal,
      cast( case when Jrn.ReferenceType = 'FKKSU' then 'X' else ' ' end as abap_boolean ) as IsTransferLine
}

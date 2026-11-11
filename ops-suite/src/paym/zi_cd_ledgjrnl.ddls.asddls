// Artifact: zi_cd_ledgjrnl.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Ledger model of the ops suite - journal lines of the universal journal through SAP's RELEASED CDS views
//          (decision of the product: the G/L side reads released APIs, never the journal / document tables) in the
//          ledger of ZI_CD_LedgCfg with every accounting attribute a reconciler needs on one row: ledger, company
//          code, fiscal year / period, document / line, document type, posting / document / entry date and time
//          (header I_JournalEntry), G/L account and its text (I_GLAccountText in the chart of accounts of the company
//          code, I_CompanyCode), posting key, debit / credit, amounts in transaction / company code / global currency
//          each with its own currency, assignment, item text, clearing document / date, profit center, segment,
//          business area, cost center, reference type / key, reversal (header reverse document, item reversal flags).
//          No WHERE: every consumer reads it by the journal's key from keys in hand (company code, fiscal year,
//          document of a G/L reference read on I_JournalEntry) or by account and posting date of a reconciled
//          account (the aggregated access path) - the journal is never searched by a reference or a text.
//          The source views' access control (DCL) is not inherited: the product's own DCL on the projections checks
//          the company code. Read-only.
// Modification log: 2026-11-11 | Generated from the product template (ledger model).
//                   2026-11-11 | Released views I_JournalEntryItem / I_JournalEntry / I_CompanyCode / I_GLAccountText
//                              | instead of the journal, document header, entry view, company code and account text
//                              | tables; element names unchanged.
// VERIFY-ADT (released views, VERIFY.md V110): release state C1 (use in key user / cloud development) of
//          I_JournalEntryItem, I_JournalEntry, I_CompanyCode, I_GLAccountText on the target release (7.58); element
//          names I_JournalEntryItem Ledger, CompanyCode, FiscalYear, AccountingDocument, LedgerGLLineItem,
//          AccountingDocumentItem, FiscalPeriod, PostingDate, GLAccount, PostingKey (fallback: VERIFY.md V110),
//          DebitCreditCode, AmountInTransactionCurrency / TransactionCurrency, AmountInCompanyCodeCurrency /
//          CompanyCodeCurrency, AmountInGlobalCurrency / GlobalCurrency, AssignmentReference, DocumentItemText,
//          ClearingJournalEntry, ClearingDate, ProfitCenter, Segment, BusinessArea, CostCenter, IsReversal,
//          IsReversed; I_JournalEntry AccountingDocumentType, DocumentDate, AccountingDocumentCreationDate,
//          CreationTime, ReferenceDocumentType, OriginalReferenceDocument, ReverseDocument,
//          ReverseDocumentFiscalYear; I_CompanyCode ChartOfAccounts; I_GLAccountText ChartOfAccounts, GLAccount,
//          Language, GLAccountLongName. Ledger = the journal's ledger as I_JournalEntryItem exposes it (one row per
//          ledger the line belongs to); PlanViz V113.
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Ledger model - journal line'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #XXL, dataClass: #TRANSACTIONAL }
define view entity ZI_CD_LedgJrnl
  as select from    I_JournalEntryItem as Jrn
    inner join      ZI_CD_LedgCfg   as Cfg on  Cfg.Ledger = Jrn.Ledger
    inner join      I_JournalEntry     as Doc on  Doc.CompanyCode        = Jrn.CompanyCode
                                              and Doc.FiscalYear         = Jrn.FiscalYear
                                              and Doc.AccountingDocument = Jrn.AccountingDocument
    left outer join I_CompanyCode      as Cc  on  Cc.CompanyCode = Jrn.CompanyCode
    left outer join I_GLAccountText    as Acc on  Acc.Language        = $session.system_language
                                              and Acc.ChartOfAccounts = Cc.ChartOfAccounts
                                              and Acc.GLAccount       = Jrn.GLAccount
{
  key Jrn.Ledger                                            as Ledger,
  key Jrn.CompanyCode                                       as CompanyCode,
  key Jrn.FiscalYear                                        as FiscalYear,
  key Jrn.AccountingDocument                                as GlDocument,
  key Jrn.LedgerGLLineItem                                  as JournalLine,
      Jrn.AccountingDocumentItem                            as GlLineItem,
      Jrn.FiscalPeriod                                      as FiscalPeriod,
      Doc.AccountingDocumentType                            as DocumentType,
      Jrn.PostingDate                                       as PostingDate,
      Doc.DocumentDate                                      as DocumentDate,
      Doc.AccountingDocumentCreationDate                    as EntryDate,
      Doc.CreationTime                                      as EntryTime,
      Jrn.GLAccount                                         as GlAccount,
      Acc.GLAccountLongName                                 as GlAccountText,
      Jrn.PostingKey                                        as PostingKey,
      Jrn.DebitCreditCode                                   as DebitCredit,
      @Semantics.amount.currencyCode: 'TransactionCurrency'
      Jrn.AmountInTransactionCurrency                       as AmountInTransCurrency,
      Jrn.TransactionCurrency                               as TransactionCurrency,
      @Semantics.amount.currencyCode: 'CompanyCodeCurrency'
      Jrn.AmountInCompanyCodeCurrency                       as AmountInCompanyCurrency,
      Jrn.CompanyCodeCurrency                               as CompanyCodeCurrency,
      @Semantics.amount.currencyCode: 'GroupCurrency'
      Jrn.AmountInGlobalCurrency                            as AmountInGroupCurrency,
      Jrn.GlobalCurrency                                    as GroupCurrency,
      Jrn.AssignmentReference                               as Assignment,
      Jrn.DocumentItemText                                  as ItemText,
      Jrn.ClearingJournalEntry                              as ClearingDocument,
      Jrn.ClearingDate                                      as ClearingDate,
      Jrn.ProfitCenter                                      as ProfitCenter,
      Jrn.Segment                                           as Segment,
      Jrn.BusinessArea                                      as BusinessArea,
      Jrn.CostCenter                                        as CostCenter,
      Doc.ReferenceDocumentType                             as ReferenceType,
      Doc.OriginalReferenceDocument                         as ReferenceKey,
      Doc.ReverseDocument                                   as ReversalDocument,
      Doc.ReverseDocumentFiscalYear                         as ReversalYear,
      // a line of a reversed document or of a reversal document is no transfer of the batch key any more
      cast( case when Doc.ReverseDocument <> '' or Jrn.IsReversal = 'X' or Jrn.IsReversed = 'X'
                 then 'X' else ' ' end as abap_boolean )    as IsReversal
}

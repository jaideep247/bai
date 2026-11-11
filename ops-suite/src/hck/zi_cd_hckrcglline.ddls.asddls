// Artifact: zi_cd_hckrcglline.ddls.asddls
// Purpose: G/L leg of the three-way reconciliation (check A_RECON_3WAY, read GET_GL_DAYS): journal lines through
//          SAP's released view I_JournalEntryItem (decision D-C8: the G/L side reads released APIs) - ledger, company
//          code, G/L account, transaction currency, posting date, reference type and the signed amount in transaction
//          currency, nothing else. No date window and no aggregation here: ZCL_CD_HCK_RECON_DAO reads it grouped
//          (SUM / COUNT per company code, account, currency, posting day, reference type) with the ledger, the
//          window and the keys of the sets (JOIN @itab), so HANA aggregates and no line is copied - the same
//          predicate as the ledger model's journal leg ZI_CD_LedgAcctDay, so the stored G/L leg and the live
//          drill-down read one source. Why a view and not ABAP SQL on I_JournalEntryItem: the released view's access
//          control (DCL) would restrict a direct ABAP SQL read to the authorizations of the user running the check
//          (the background user), silently dropping lines from a reconciliation; this view has no access control
//          of its own (a control reads every line of the configured accounts, as the table read did) and is read
//          only by the DAO. Read-only.
// Modification log: 2026-11-11 | Initial version (decision D-C8 changed: G/L leg of A_RECON_3WAY on the released
//                              | view instead of the journal table).
// VERIFY-ADT (VERIFY_Suite.md / framework VERIFY.md V110): I_JournalEntryItem release state C1 on 7.58; elements
//          SourceLedger, Ledger, CompanyCode, FiscalYear, AccountingDocument, LedgerGLLineItem, GLAccount,
//          TransactionCurrency, PostingDate, ReferenceDocumentType, AmountInTransactionCurrency. PlanViz LDG-PV6
//          (Performance_Review.md section 13): the grouped read of the window keeps the ledger / company code /
//          account / posting date predicates on the journal table - same runtime as the former table read.
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'HCK reconciliation G/L line'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #XXL, dataClass: #TRANSACTIONAL }
@VDM.viewType: #BASIC
define view entity ZI_CD_HckRcGlLine
  as select from I_JournalEntryItem as Jrn
{
  key Jrn.SourceLedger                                      as SourceLedger,
  key Jrn.CompanyCode                                       as CompanyCode,
  key Jrn.FiscalYear                                        as FiscalYear,
  key Jrn.AccountingDocument                                as AccountingDocument,
  key Jrn.LedgerGLLineItem                                  as LedgerGLLineItem,
  key Jrn.Ledger                                            as Ledger,
      Jrn.GLAccount                                         as GLAccount,
      Jrn.TransactionCurrency                               as TransactionCurrency,
      Jrn.PostingDate                                       as PostingDate,
      Jrn.ReferenceDocumentType                             as ReferenceDocumentType,
      @Semantics.amount.currencyCode: 'TransactionCurrency'
      Jrn.AmountInTransactionCurrency                       as AmountInTransactionCurrency
}

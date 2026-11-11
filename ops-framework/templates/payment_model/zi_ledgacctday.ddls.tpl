// Artifact: zi_{{p}}_ledgacctday.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Ledger model of the {{CONSUMER}} - journal leg of the group reconciliation: universal journal lines of the
//          reconciled accounts (ZI_{{P}}_LedgAcct) in the ledger of ZI_{{P}}_LedgCfg, read through the released view
//          I_JournalEntryItem, aggregated per company code, G/L account, transaction currency and posting date on the
//          database (the access path ledger, company code, account, posting date; callers always restrict the
//          posting date) - total, the part of the G/L documents of subledger batch keys (reference type
//          {{GL_REFTYPE}}) and the rest (other postings: bank statement, manual), line count. Signed as the journal
//          (amount in transaction currency); never across currencies. Read-only.
// Modification log: {{SINCE}} | Generated from the product template (ledger model).
//                   2026-11-11 | Released view I_JournalEntryItem instead of the journal table; element names unchanged.
// VERIFY-ADT: SUM of a CASE over a DEC cast of a CURR element of a released view (7.58); I_JournalEntryItem C1,
//             elements Ledger, CompanyCode, GLAccount, TransactionCurrency, PostingDate, ReferenceDocumentType,
//             AmountInTransactionCurrency (VERIFY.md V110). PlanViz on the largest day of the consumer (V113, the
//             consumer's performance review): the ledger / account / date predicates reach the journal table
//             through the released view's stack - no scan of the journal.
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Ledger model - journal per account and day'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #XXL, dataClass: #TRANSACTIONAL }
define view entity ZI_{{P}}_LedgAcctDay
  as select from I_JournalEntryItem as Jrn
    inner join   ZI_{{P}}_LedgCfg    as Cfg on  Cfg.Ledger = Jrn.Ledger
    inner join   ZI_{{P}}_LedgAcct   as Acc on  Acc.CompanyCode = Jrn.CompanyCode
                                            and Acc.GlAccount   = Jrn.GLAccount
                                            and Acc.Currency    = Jrn.TransactionCurrency
{
  key Jrn.CompanyCode                                       as CompanyCode,
  key Jrn.GLAccount                                         as GlAccount,
  key Jrn.TransactionCurrency                               as Currency,
  key Jrn.PostingDate                                       as PostingDate,
      cast( sum( cast( Jrn.AmountInTransactionCurrency as abap.dec( 23, 2 ) ) )
            as abap.dec( 23, 2 ) )                          as JournalAmount,
      cast( sum( case when Jrn.ReferenceDocumentType = '{{GL_REFTYPE}}'
                      then cast( Jrn.AmountInTransactionCurrency as abap.dec( 23, 2 ) ) else 0 end )
            as abap.dec( 23, 2 ) )                          as TransferAmount,
      cast( count( * ) as abap.int4 )                       as JournalLineCount
}
group by
  Jrn.CompanyCode,
  Jrn.GLAccount,
  Jrn.TransactionCurrency,
  Jrn.PostingDate

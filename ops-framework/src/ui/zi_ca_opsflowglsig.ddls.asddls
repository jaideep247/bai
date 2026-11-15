// Artifact: zi_ca_opsflowglsig.ddls.asddls
// Purpose: Account flow reconciliation - journal lines of the flow accounts in the posting date window, read through
//          SAP's released view I_JournalEntryItem (rule D-C8: the G/L side reads released APIs) and aggregated on the
//          database to their stage signature: account of the flow, transaction currency, reference transaction
//          (AWTYP), document type (BLART), debit / credit - amount and line count. The ledger, company code, G/L account
//          range and currency range of the account are join conditions, the window a WHERE on the posting date, so the
//          predicates reach the journal table (ACDOCA RLDNR / RBUKRS / RACCT / BUDAT) and only the signatures - a few
//          rows per account and day range - leave HANA. Every journal line of a flow account is here, including the
//          G/L transfer lines of a subledger-posted account (line source F, AWTYP FKKSU: reached G/L). No line is classified here
//          (ZI_CA_OpsFlowGlMin). The released view's access control is not applied through this view: the dashboard's
//          own DCL (area, company code) is. Read-only.
// Modification log: 2026-11-15 | Initial version (build G: account flow reconciliation).
// VERIFY-ADT (V147): I_JournalEntryItem release state C1 on 7.58 and the elements Ledger, CompanyCode, GLAccount,
//          TransactionCurrency, AmountInTransactionCurrency, PostingDate, ReferenceDocumentType, DebitCreditCode (V110)
//          and AccountingDocumentType (on the item view; fallback: the association _JournalEntry of the item view, or
//          I_JournalEntry by company code / fiscal year / document - V110 lists it there); >= / <= between fields of two
//          sources in an ON condition; SUM of a DEC cast of a CURR element (as the ledger model template, V112).
//          PlanViz FLOW-PV1: aggregation on HANA, ledger / company code / account / posting date predicates on ACDOCA.
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Account flow: journal signatures'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #XXL, dataClass: #TRANSACTIONAL }
define view entity ZI_CA_OpsFlowGlSig
  with parameters
    P_DateFrom : abap.dats,
    P_DateTo   : abap.dats
  as select from I_JournalEntryItem as Jrn
    inner join   ZI_CA_OpsFlowAcct  as Acc on  Acc.CompanyCode         =  Jrn.CompanyCode
                                           and Acc.Ledger              =  Jrn.Ledger
                                           and Acc.GLAccountFrom       <= Jrn.GLAccount
                                           and Acc.GLAccountTo         >= Jrn.GLAccount
                                           and Acc.CurrencyLow         <= Jrn.TransactionCurrency
                                           and Acc.CurrencyHigh        >= Jrn.TransactionCurrency
{
  key Acc.Area                                              as Area,
  key Acc.FlowId                                            as FlowId,
  key Acc.FlowAccount                                       as FlowAccount,
  key cast( Jrn.TransactionCurrency as abap.char( 5 ) )     as Currency,
  key Jrn.ReferenceDocumentType                             as ReferenceType,
  key Jrn.AccountingDocumentType                            as DocumentType,
  key Jrn.DebitCreditCode                                   as DebitCredit,
      Acc.LineSource                                        as LineSource,
      cast( sum( cast( Jrn.AmountInTransactionCurrency as abap.dec( 23, 2 ) ) )
            as abap.dec( 23, 2 ) )                          as Amount,
      cast( count( * ) as abap.int4 )                       as LineCount
}
where
      Jrn.PostingDate >= $parameters.P_DateFrom
  and Jrn.PostingDate <= $parameters.P_DateTo
group by
  Acc.Area,
  Acc.FlowId,
  Acc.FlowAccount,
  Acc.LineSource,
  Jrn.TransactionCurrency,
  Jrn.ReferenceDocumentType,
  Jrn.AccountingDocumentType,
  Jrn.DebitCreditCode

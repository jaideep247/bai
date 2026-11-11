// Artifact: zi_cd_ebsglline.ddls.asddls
// Purpose: Journal lines of the bank G/L balance of the EBS validation (rule R18, ZCL_CD_EBS_SAP_DAO=>GET_GL_BALANCES)
//          through SAP's released view I_JournalEntryItem (decision D-C8: the G/L side reads released APIs) - ledger,
//          company code, G/L account, balance transaction currency, posting date and the signed amount in balance
//          transaction currency (ACDOCA RLDNR, RBUKRS, RACCT, RTCUR, BUDAT, TSL), nothing else. No aggregation here:
//          the DAO sums it per closing statement (JOIN @itab on company code, account, currency, posting date up to the
//          statement date) with the ledger EBS_GL_LEDGER, so HANA aggregates and no line is copied. Why a view and not
//          ABAP SQL on I_JournalEntryItem: the released view's access control (DCL) would restrict a direct ABAP SQL
//          read to the authorizations of the user running the validation (a job), and a line filtered away would
//          change the balance compared with the bank's closing balance; this view has no access control of its own
//          and is read only by the DAO. Read-only.
// Modification log: 2026-11-11 | Initial version (decision D-C8 extended to the suite's G/L reads: replaces the ACDOCA
//                              | aggregate of the bank G/L balance).
// VERIFY-ADT (VERIFY_Suite.md V123; elements as framework VERIFY.md V110): I_JournalEntryItem release state C1 on 7.58;
//          elements SourceLedger, Ledger, CompanyCode, FiscalYear, AccountingDocument, LedgerGLLineItem, GLAccount,
//          PostingDate, BalanceTransactionCurrency (RTCUR), AmountInBalanceTransacCrcy (TSL). Totals equal the former
//          ACDOCA read per request (QA1, also with balance carry-forward and archived / extracted periods of the bank
//          account). Fallback if the balance transaction currency pair is not exposed: GET_GL_BALANCES goes back to the
//          table read (same SQL as before 2026-11-11) - never the transaction currency pair (WSL / RWCUR is a different
//          amount). PlanViz GLV-PV5 (Performance_Review.md section 14).
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'EBS bank G/L balance line (released view)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #XXL, dataClass: #TRANSACTIONAL }
@VDM.viewType: #BASIC
define view entity ZI_CD_EbsGlLine
  as select from I_JournalEntryItem as Jrn
{
  key Jrn.SourceLedger                                      as SourceLedger,
  key Jrn.CompanyCode                                       as CompanyCode,
  key Jrn.FiscalYear                                        as FiscalYear,
  key Jrn.AccountingDocument                                as AccountingDocument,
  key Jrn.LedgerGLLineItem                                  as LedgerGLLineItem,
  key Jrn.Ledger                                            as Ledger,
      Jrn.GLAccount                                         as GLAccount,
      Jrn.BalanceTransactionCurrency                        as BalanceTransactionCurrency,
      Jrn.PostingDate                                       as PostingDate,
      @Semantics.amount.currencyCode: 'BalanceTransactionCurrency'
      Jrn.AmountInBalanceTransacCrcy                        as AmountInBalanceTransacCrcy
}

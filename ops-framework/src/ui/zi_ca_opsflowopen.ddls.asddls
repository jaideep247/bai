// Artifact: zi_ca_opsflowopen.ddls.asddls
// Purpose: Account flow reconciliation - opening position of every flow account and currency: the balance up to the
//          day before "from". Not a sum over years of lines: the fiscal year of "from" is taken from the company
//          code's fiscal year variant (I_CompanyCode -> I_FiscalCalendarDate), and the opening is the balance carried
//          forward into that year (period 000 of the journal) plus the lines of that year posted before "from" - the
//          period balance approach of the general ledger, read through the released views. The ledger, company code,
//          account range and currency range are join conditions. Read-only.
// Modification log: 2026-11-15 | Initial version (build G: account flow reconciliation).
// VERIFY-ADT (V147): I_CompanyCode-FiscalYearVariant, I_FiscalCalendarDate (release state C1 on 7.58; elements
//          FiscalYearVariant, CalendarDate, FiscalYear), I_JournalEntryItem-FiscalYear / FiscalPeriod (V110) and that the
//          balance carry-forward lines (period 000) are rows of I_JournalEntryItem; a parameter in an ON condition.
//          Business (V148): the carry-forward of the year of "from" has run (FAGLGVTR) - before it, the opening misses
//          the prior years (the dashboard shows what the journal holds; the limit is in docs/ACCOUNT_FLOW.md). Fallback
//          if period 000 is not exposed: the lines of every year before "from" (a sum over years: PlanViz FLOW-PV2
//          decides whether it may run on the busiest account). PlanViz FLOW-PV2: carry-forward + year-to-date only.
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Account flow: opening position'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #XXL, dataClass: #TRANSACTIONAL }
define view entity ZI_CA_OpsFlowOpen
  with parameters
    P_DateFrom : abap.dats
  as select from I_JournalEntryItem   as Jrn
    inner join   ZI_CA_OpsFlowAcct    as Acc on  Acc.CompanyCode   =  Jrn.CompanyCode
                                             and Acc.Ledger        =  Jrn.Ledger
                                             and Acc.GLAccountFrom <= Jrn.GLAccount
                                             and Acc.GLAccountTo   >= Jrn.GLAccount
                                             and Acc.CurrencyLow   <= Jrn.TransactionCurrency
                                             and Acc.CurrencyHigh  >= Jrn.TransactionCurrency
    inner join   I_CompanyCode        as Cc  on  Cc.CompanyCode = Jrn.CompanyCode
    inner join   I_FiscalCalendarDate as Cal on  Cal.FiscalYearVariant = Cc.FiscalYearVariant
                                             and Cal.CalendarDate      = $parameters.P_DateFrom
                                             and Cal.FiscalYear        = Jrn.FiscalYear
{
  key Acc.Area                                              as Area,
  key Acc.FlowId                                            as FlowId,
  key Acc.FlowAccount                                       as FlowAccount,
  key cast( Jrn.TransactionCurrency as abap.char( 5 ) )     as Currency,
      cast( sum( cast( Jrn.AmountInTransactionCurrency as abap.dec( 23, 2 ) ) )
            as abap.dec( 23, 2 ) )                          as OpeningAmount
}
where
     Jrn.FiscalPeriod = '000'
  or Jrn.PostingDate  < $parameters.P_DateFrom
group by
  Acc.Area,
  Acc.FlowId,
  Acc.FlowAccount,
  Jrn.TransactionCurrency

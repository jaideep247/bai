// Artifact: zi_ca_opsflowfisig.ddls.asddls
// Purpose: Account flow reconciliation - FI-CA document lines (ZI_CA_OpsFlowFiLine) of the subledger-posted flow
//          accounts (line source F) in the posting date window, aggregated on the database to their stage signature:
//          account of the flow, currency, FI-CA document type, origin key, main / sub-transaction, debit / credit -
//          amount and line count. Company code, G/L account range and currency range are join conditions,
//          the window a WHERE on the posting date (the clearing date for a cleared item). Read-only.
// Modification log: 2026-11-15 | Initial version (build G: account flow reconciliation).
// VERIFY-ADT (V147): >= / <= between fields of two sources in an ON condition; PlanViz FLOW-PV3.
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Account flow: FI-CA signatures'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #XXL, dataClass: #TRANSACTIONAL }
define view entity ZI_CA_OpsFlowFiSig
  with parameters
    P_DateFrom : abap.dats,
    P_DateTo   : abap.dats
  as select from ZI_CA_OpsFlowFiLine as Ln
    inner join   ZI_CA_OpsFlowAcct   as Acc on  Acc.CompanyCode   =  Ln.CompanyCode
                                            and Acc.LineSource    =  'F'
                                            and Acc.GLAccountFrom <= Ln.GLAccount
                                            and Acc.GLAccountTo   >= Ln.GLAccount
                                            and Acc.CurrencyLow   <= Ln.Currency
                                            and Acc.CurrencyHigh  >= Ln.Currency
{
  key Acc.Area                                              as Area,
  key Acc.FlowId                                            as FlowId,
  key Acc.FlowAccount                                       as FlowAccount,
  key Ln.Currency                                           as Currency,
  key Ln.DocumentType                                       as DocumentType,
  key Ln.Origin                                             as Origin,
  key Ln.MainTransaction                                    as MainTransaction,
  key Ln.SubTransaction                                     as SubTransaction,
  key Ln.DebitCredit                                        as DebitCredit,
      cast( sum( Ln.Amount ) as abap.dec( 23, 2 ) )         as Amount,
      cast( count( * ) as abap.int4 )                       as LineCount
}
where
      Ln.PostingDate >= $parameters.P_DateFrom
  and Ln.PostingDate <= $parameters.P_DateTo
group by
  Acc.Area,
  Acc.FlowId,
  Acc.FlowAccount,
  Ln.Currency,
  Ln.DocumentType,
  Ln.Origin,
  Ln.MainTransaction,
  Ln.SubTransaction,
  Ln.DebitCredit

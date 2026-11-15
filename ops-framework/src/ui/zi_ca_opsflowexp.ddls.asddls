// Artifact: zi_ca_opsflowexp.ddls.asddls
// Purpose: Account flow reconciliation - expected postings (shown in brackets): a stage with EXPECT_FROM / EXPECT_TO
//          will post what the checks hold open on the accounts of role EXPECT_FROM (it clears them) against the
//          accounts of role EXPECT_TO. Both sides from the evaluated position of the EXPECT_FROM account (accounted
//          for at "to", ZI_CA_OpsFlowPos, status E only): the clearing side on that account opposite to its balance,
//          the counter side on every account of role EXPECT_TO of the same flow, company code and currency (one is
//          expected - problem 326 of the evaluation otherwise). E.g. returns clearing holds credit 300 from an open
//          returns lot item: the returns lot stage expects debit 300 on returns clearing and credit 300 (reopen) on the
//          payable. Nothing posted, nothing compared of its own. Read-only.
// Modification log: 2026-11-15 | Initial version (build G: account flow reconciliation).
// VERIFY-ADT (V147): UNION ALL of two parameterised branches.
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Account flow: expected postings'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #S, dataClass: #TRANSACTIONAL }
define view entity ZI_CA_OpsFlowExp
  with parameters
    P_DateFrom : abap.dats,
    P_DateTo   : abap.dats
  as select from ZI_CA_OpsFlowPos( P_DateFrom : $parameters.P_DateFrom,
                                   P_DateTo   : $parameters.P_DateTo ) as Pos
    inner join   zca_ops_flwstg                                        as Stg on  Stg.area        = Pos.Area
                                                                              and Stg.flow_id     = Pos.FlowId
                                                                              and Stg.expect_from = Pos.AccountRole
                                                                              and Stg.active      = 'X'
{
  key Pos.Area                                              as Area,
  key Pos.FlowId                                            as FlowId,
  key Pos.FlowAccount                                       as FlowAccount,
  key Pos.Currency                                          as Currency,
  key Stg.stage_id                                          as StageId,
      cast( case when Pos.AccountedAmount < 0 then Pos.AccountedAmount * -1 else 0 end
            as abap.dec( 23, 2 ) )                          as ExpectedDebit,
      cast( case when Pos.AccountedAmount > 0 then Pos.AccountedAmount else 0 end
            as abap.dec( 23, 2 ) )                          as ExpectedCredit
}
where
  Pos.EvalStatus = 'E'
union all
  select from ZI_CA_OpsFlowPos( P_DateFrom : $parameters.P_DateFrom,
                                P_DateTo   : $parameters.P_DateTo ) as Pos
    inner join zca_ops_flwstg                                       as Stg on  Stg.area        = Pos.Area
                                                                           and Stg.flow_id     = Pos.FlowId
                                                                           and Stg.expect_from = Pos.AccountRole
                                                                           and Stg.active      = 'X'
    inner join ZI_CA_OpsFlowAcct                                    as Cnt on  Cnt.Area         =  Pos.Area
                                                                           and Cnt.FlowId       =  Pos.FlowId
                                                                           and Cnt.AccountRole  =  Stg.expect_to
                                                                           and Cnt.CompanyCode  =  Pos.CompanyCode
                                                                           and Cnt.CurrencyLow  <= Pos.Currency
                                                                           and Cnt.CurrencyHigh >= Pos.Currency
{
  key Pos.Area                                              as Area,
  key Pos.FlowId                                            as FlowId,
  key Cnt.FlowAccount                                       as FlowAccount,
  key Pos.Currency                                          as Currency,
  key Stg.stage_id                                          as StageId,
      cast( case when Pos.AccountedAmount > 0 then Pos.AccountedAmount else 0 end
            as abap.dec( 23, 2 ) )                          as ExpectedDebit,
      cast( case when Pos.AccountedAmount < 0 then Pos.AccountedAmount * -1 else 0 end
            as abap.dec( 23, 2 ) )                          as ExpectedCredit
}
where
  Pos.EvalStatus = 'E'

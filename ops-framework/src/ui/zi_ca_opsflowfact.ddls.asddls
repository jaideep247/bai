// Artifact: zi_ca_opsflowfact.ddls.asddls
// Purpose: Account flow reconciliation - the rows of the matrix, one branch each (the cube ZI_CA_OpsFlowCube sums
//          them per stage row and account column): S movement by stage (ZI_CA_OpsFlowMove - debit / credit of the
//          account's own lines; the G/L transfer lines of a subledger-posted account as reached G/L, MemoDebit /
//          MemoCredit), Z every active stage of the flow for every account and currency (so a stage without postings
//          still shows its row and control tag), E expected postings in brackets (ZI_CA_OpsFlowExp), then the
//          reserved rows: MOVEMENT (the sum of the stage rows, never the reached G/L), OPENING and CLOSING (the
//          position, a debit balance as debit, a credit balance as credit) and UNEXPLAINED (closing minus what the
//          checks account for; with the evaluation status - not evaluated counts 1 and shows no amount, grey). Every
//          figure comes from a posting or an open item of a check. Read-only.
// Modification log: 2026-11-15 | Initial version (build G: account flow reconciliation).
// VERIFY-ADT (V147): UNION ALL of seven branches with parameters and typed literals (V112).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Account flow: matrix rows'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define view entity ZI_CA_OpsFlowFact
  with parameters
    P_DateFrom : abap.dats,
    P_DateTo   : abap.dats
  as select from ZI_CA_OpsFlowMove( P_DateFrom : $parameters.P_DateFrom,
                                    P_DateTo   : $parameters.P_DateTo ) as Mv
{
  key Mv.Area                                               as Area,
  key Mv.FlowId                                             as FlowId,
  key Mv.FlowAccount                                        as FlowAccount,
  key Mv.Currency                                           as Currency,
  key Mv.StageId                                            as StageId,
  key cast( 'S' as abap.char( 1 ) )                         as RowKind,
  key Mv.LineSource                                         as LineSource,
  key Mv.ReferenceType                                      as ReferenceType,
  key Mv.DocumentType                                       as DocumentType,
  key Mv.Origin                                             as Origin,
  key Mv.MainTransaction                                    as MainTransaction,
  key Mv.SubTransaction                                     as SubTransaction,
  key Mv.DebitCredit                                        as DebitCredit,
      Mv.RuleId                                             as RuleId,
      cast( '' as zca_ops_flow_evst )                       as EvalStatus,
      cast( case when Mv.IsMemo = 'X' then 0 else Mv.DebitAmount end as abap.dec( 23, 2 ) )  as DebitAmount,
      cast( case when Mv.IsMemo = 'X' then 0 else Mv.CreditAmount end as abap.dec( 23, 2 ) ) as CreditAmount,
      cast( 0 as abap.dec( 23, 2 ) )                        as ExpectedDebit,
      cast( 0 as abap.dec( 23, 2 ) )                        as ExpectedCredit,
      cast( case when Mv.IsMemo = 'X' then Mv.DebitAmount else 0 end as abap.dec( 23, 2 ) )  as MemoDebit,
      cast( case when Mv.IsMemo = 'X' then Mv.CreditAmount else 0 end as abap.dec( 23, 2 ) ) as MemoCredit,
      Mv.LineCount                                          as LineCount,
      cast( 0 as abap.int4 )                                as NotEvaluatedCount
}
union all
  select from ZI_CA_OpsFlowPos( P_DateFrom : $parameters.P_DateFrom,
                                P_DateTo   : $parameters.P_DateTo ) as Pos
    inner join zca_ops_flwstg                                       as Stg on  Stg.area    = Pos.Area
                                                                           and Stg.flow_id = Pos.FlowId
                                                                           and Stg.active  = 'X'
{
  key Pos.Area                                              as Area,
  key Pos.FlowId                                            as FlowId,
  key Pos.FlowAccount                                       as FlowAccount,
  key Pos.Currency                                          as Currency,
  key Stg.stage_id                                          as StageId,
  key cast( 'Z' as abap.char( 1 ) )                         as RowKind,
  key cast( '' as abap.char( 1 ) )                          as LineSource,
  key cast( '' as abap.char( 5 ) )                          as ReferenceType,
  key cast( '' as abap.char( 2 ) )                          as DocumentType,
  key cast( '' as abap.char( 2 ) )                          as Origin,
  key cast( '' as abap.char( 4 ) )                          as MainTransaction,
  key cast( '' as abap.char( 4 ) )                          as SubTransaction,
  key cast( '' as abap.char( 1 ) )                          as DebitCredit,
      cast( '' as abap.char( 20 ) )                         as RuleId,
      cast( '' as zca_ops_flow_evst )                       as EvalStatus,
      cast( 0 as abap.dec( 23, 2 ) )                        as DebitAmount,
      cast( 0 as abap.dec( 23, 2 ) )                        as CreditAmount,
      cast( 0 as abap.dec( 23, 2 ) )                        as ExpectedDebit,
      cast( 0 as abap.dec( 23, 2 ) )                        as ExpectedCredit,
      cast( 0 as abap.dec( 23, 2 ) )                        as MemoDebit,
      cast( 0 as abap.dec( 23, 2 ) )                        as MemoCredit,
      cast( 0 as abap.int4 )                                as LineCount,
      cast( 0 as abap.int4 )                                as NotEvaluatedCount
}
union all
  select from ZI_CA_OpsFlowExp( P_DateFrom : $parameters.P_DateFrom,
                                P_DateTo   : $parameters.P_DateTo ) as Ex
{
  key Ex.Area                                               as Area,
  key Ex.FlowId                                             as FlowId,
  key Ex.FlowAccount                                        as FlowAccount,
  key Ex.Currency                                           as Currency,
  key Ex.StageId                                            as StageId,
  key cast( 'E' as abap.char( 1 ) )                         as RowKind,
  key cast( '' as abap.char( 1 ) )                          as LineSource,
  key cast( '' as abap.char( 5 ) )                          as ReferenceType,
  key cast( '' as abap.char( 2 ) )                          as DocumentType,
  key cast( '' as abap.char( 2 ) )                          as Origin,
  key cast( '' as abap.char( 4 ) )                          as MainTransaction,
  key cast( '' as abap.char( 4 ) )                          as SubTransaction,
  key cast( '' as abap.char( 1 ) )                          as DebitCredit,
      cast( '' as abap.char( 20 ) )                         as RuleId,
      cast( '' as zca_ops_flow_evst )                       as EvalStatus,
      cast( 0 as abap.dec( 23, 2 ) )                        as DebitAmount,
      cast( 0 as abap.dec( 23, 2 ) )                        as CreditAmount,
      Ex.ExpectedDebit                                      as ExpectedDebit,
      Ex.ExpectedCredit                                     as ExpectedCredit,
      cast( 0 as abap.dec( 23, 2 ) )                        as MemoDebit,
      cast( 0 as abap.dec( 23, 2 ) )                        as MemoCredit,
      cast( 0 as abap.int4 )                                as LineCount,
      cast( 0 as abap.int4 )                                as NotEvaluatedCount
}
union all
  select from ZI_CA_OpsFlowMove( P_DateFrom : $parameters.P_DateFrom,
                                 P_DateTo   : $parameters.P_DateTo ) as Mv
{
  key Mv.Area                                               as Area,
  key Mv.FlowId                                             as FlowId,
  key Mv.FlowAccount                                        as FlowAccount,
  key Mv.Currency                                           as Currency,
  key cast( 'MOVEMENT' as abap.char( 20 ) )                 as StageId,
  key cast( 'M' as abap.char( 1 ) )                         as RowKind,
  key Mv.LineSource                                         as LineSource,
  key Mv.ReferenceType                                      as ReferenceType,
  key Mv.DocumentType                                       as DocumentType,
  key Mv.Origin                                             as Origin,
  key Mv.MainTransaction                                    as MainTransaction,
  key Mv.SubTransaction                                     as SubTransaction,
  key Mv.DebitCredit                                        as DebitCredit,
      Mv.RuleId                                             as RuleId,
      cast( '' as zca_ops_flow_evst )                       as EvalStatus,
      Mv.DebitAmount                                        as DebitAmount,
      Mv.CreditAmount                                       as CreditAmount,
      cast( 0 as abap.dec( 23, 2 ) )                        as ExpectedDebit,
      cast( 0 as abap.dec( 23, 2 ) )                        as ExpectedCredit,
      cast( 0 as abap.dec( 23, 2 ) )                        as MemoDebit,
      cast( 0 as abap.dec( 23, 2 ) )                        as MemoCredit,
      Mv.LineCount                                          as LineCount,
      cast( 0 as abap.int4 )                                as NotEvaluatedCount
}
where
  Mv.IsMemo = ' '
union all
  select from ZI_CA_OpsFlowPos( P_DateFrom : $parameters.P_DateFrom,
                                P_DateTo   : $parameters.P_DateTo ) as Pos
{
  key Pos.Area                                              as Area,
  key Pos.FlowId                                            as FlowId,
  key Pos.FlowAccount                                       as FlowAccount,
  key Pos.Currency                                          as Currency,
  key cast( 'OPENING' as abap.char( 20 ) )                  as StageId,
  key cast( 'O' as abap.char( 1 ) )                         as RowKind,
  key cast( '' as abap.char( 1 ) )                          as LineSource,
  key cast( '' as abap.char( 5 ) )                          as ReferenceType,
  key cast( '' as abap.char( 2 ) )                          as DocumentType,
  key cast( '' as abap.char( 2 ) )                          as Origin,
  key cast( '' as abap.char( 4 ) )                          as MainTransaction,
  key cast( '' as abap.char( 4 ) )                          as SubTransaction,
  key cast( '' as abap.char( 1 ) )                          as DebitCredit,
      cast( '' as abap.char( 20 ) )                         as RuleId,
      cast( '' as zca_ops_flow_evst )                       as EvalStatus,
      cast( case when Pos.OpeningAmount > 0 then Pos.OpeningAmount else 0 end as abap.dec( 23, 2 ) ) as DebitAmount,
      cast( case when Pos.OpeningAmount < 0 then Pos.OpeningAmount * -1 else 0 end as abap.dec( 23, 2 ) ) as CreditAmount,
      cast( 0 as abap.dec( 23, 2 ) )                        as ExpectedDebit,
      cast( 0 as abap.dec( 23, 2 ) )                        as ExpectedCredit,
      cast( 0 as abap.dec( 23, 2 ) )                        as MemoDebit,
      cast( 0 as abap.dec( 23, 2 ) )                        as MemoCredit,
      cast( 0 as abap.int4 )                                as LineCount,
      cast( 0 as abap.int4 )                                as NotEvaluatedCount
}
union all
  select from ZI_CA_OpsFlowPos( P_DateFrom : $parameters.P_DateFrom,
                                P_DateTo   : $parameters.P_DateTo ) as Pos
{
  key Pos.Area                                              as Area,
  key Pos.FlowId                                            as FlowId,
  key Pos.FlowAccount                                       as FlowAccount,
  key Pos.Currency                                          as Currency,
  key cast( 'CLOSING' as abap.char( 20 ) )                  as StageId,
  key cast( 'C' as abap.char( 1 ) )                         as RowKind,
  key cast( '' as abap.char( 1 ) )                          as LineSource,
  key cast( '' as abap.char( 5 ) )                          as ReferenceType,
  key cast( '' as abap.char( 2 ) )                          as DocumentType,
  key cast( '' as abap.char( 2 ) )                          as Origin,
  key cast( '' as abap.char( 4 ) )                          as MainTransaction,
  key cast( '' as abap.char( 4 ) )                          as SubTransaction,
  key cast( '' as abap.char( 1 ) )                          as DebitCredit,
      cast( '' as abap.char( 20 ) )                         as RuleId,
      cast( '' as zca_ops_flow_evst )                       as EvalStatus,
      cast( case when Pos.ClosingAmount > 0 then Pos.ClosingAmount else 0 end as abap.dec( 23, 2 ) ) as DebitAmount,
      cast( case when Pos.ClosingAmount < 0 then Pos.ClosingAmount * -1 else 0 end as abap.dec( 23, 2 ) ) as CreditAmount,
      cast( 0 as abap.dec( 23, 2 ) )                        as ExpectedDebit,
      cast( 0 as abap.dec( 23, 2 ) )                        as ExpectedCredit,
      cast( 0 as abap.dec( 23, 2 ) )                        as MemoDebit,
      cast( 0 as abap.dec( 23, 2 ) )                        as MemoCredit,
      cast( 0 as abap.int4 )                                as LineCount,
      cast( 0 as abap.int4 )                                as NotEvaluatedCount
}
union all
  select from ZI_CA_OpsFlowPos( P_DateFrom : $parameters.P_DateFrom,
                                P_DateTo   : $parameters.P_DateTo ) as Pos
{
  key Pos.Area                                              as Area,
  key Pos.FlowId                                            as FlowId,
  key Pos.FlowAccount                                       as FlowAccount,
  key Pos.Currency                                          as Currency,
  key cast( 'UNEXPLAINED' as abap.char( 20 ) )              as StageId,
  key cast( 'U' as abap.char( 1 ) )                         as RowKind,
  key cast( '' as abap.char( 1 ) )                          as LineSource,
  key cast( '' as abap.char( 5 ) )                          as ReferenceType,
  key cast( '' as abap.char( 2 ) )                          as DocumentType,
  key cast( '' as abap.char( 2 ) )                          as Origin,
  key cast( '' as abap.char( 4 ) )                          as MainTransaction,
  key cast( '' as abap.char( 4 ) )                          as SubTransaction,
  key cast( '' as abap.char( 1 ) )                          as DebitCredit,
      cast( '' as abap.char( 20 ) )                         as RuleId,
      Pos.EvalStatus                                        as EvalStatus,
      cast( case when Pos.UnexplainedAmount > 0 then Pos.UnexplainedAmount else 0 end as abap.dec( 23, 2 ) ) as DebitAmount,
      cast( case when Pos.UnexplainedAmount < 0 then Pos.UnexplainedAmount * -1 else 0 end
            as abap.dec( 23, 2 ) )                          as CreditAmount,
      cast( 0 as abap.dec( 23, 2 ) )                        as ExpectedDebit,
      cast( 0 as abap.dec( 23, 2 ) )                        as ExpectedCredit,
      cast( 0 as abap.dec( 23, 2 ) )                        as MemoDebit,
      cast( 0 as abap.dec( 23, 2 ) )                        as MemoCredit,
      cast( 0 as abap.int4 )                                as LineCount,
      cast( case when Pos.EvalStatus = 'N' then 1 else 0 end as abap.int4 ) as NotEvaluatedCount
}

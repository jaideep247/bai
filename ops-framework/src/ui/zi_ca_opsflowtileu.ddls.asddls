// Artifact: zi_ca_opsflowtileu.ddls.asddls
// Purpose: Account flow reconciliation - the parts of the tiles above the matrix, per flow, company code and currency:
//          from the stage rows (a tile row of ZCA_OPS_FLWTIL: the debit or credit of a stage on the accounts of a role)
//          the amounts requested, paid / settled by the bank and matched and cleared; from the evaluated positions (EVAL_CATEGORY
//          of the account) what is still in transit and in clarification (amount and items), the unexplained amount
//          (absolute) and the accounts not evaluated. Summed by ZI_CA_OpsFlowTileS. Read-only.
// Modification log: 2026-11-15 | Initial version (build G: account flow reconciliation).
// VERIFY-ADT (V147): abs( ) of a DEC expression, UNION ALL of parameterised branches.
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Account flow: tile parts'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #M, dataClass: #TRANSACTIONAL }
define view entity ZI_CA_OpsFlowTileU
  with parameters
    P_DateFrom : abap.dats,
    P_DateTo   : abap.dats
  as select from ZI_CA_OpsFlowMove( P_DateFrom : $parameters.P_DateFrom,
                                    P_DateTo   : $parameters.P_DateTo ) as Mv
    inner join   ZI_CA_OpsFlowAcct                                      as Acc on  Acc.Area        = Mv.Area
                                                                               and Acc.FlowId      = Mv.FlowId
                                                                               and Acc.FlowAccount = Mv.FlowAccount
    inner join   zca_ops_flwtil                                         as Til on  Til.area     = Mv.Area
                                                                               and Til.flow_id  = Mv.FlowId
                                                                               and Til.stage_id = Mv.StageId
                                                                               and Til.role     = Acc.AccountRole
                                                                               and Til.active   = 'X'
{
  key Mv.Area                                               as Area,
  key Mv.FlowId                                             as FlowId,
  key Acc.CompanyCode                                       as CompanyCode,
  key Mv.Currency                                           as Currency,
      cast( case when Til.tile <> 'REQUESTED' then 0
                 when Til.side = 'D' then Mv.DebitAmount
                 else Mv.CreditAmount end as abap.dec( 23, 2 ) ) as RequestedAmount,
      cast( case when Til.tile <> 'PAID' then 0
                 when Til.side = 'D' then Mv.DebitAmount
                 else Mv.CreditAmount end as abap.dec( 23, 2 ) ) as PaidAmount,
      cast( case when Til.tile <> 'CLEARED' then 0
                 when Til.side = 'D' then Mv.DebitAmount
                 else Mv.CreditAmount end as abap.dec( 23, 2 ) ) as ClearedAmount,
      cast( 0 as abap.dec( 23, 2 ) )                        as InTransitAmount,
      cast( 0 as abap.dec( 23, 2 ) )                        as InClarificationAmount,
      cast( 0 as abap.int4 )                                as InClarificationItems,
      cast( 0 as abap.dec( 23, 2 ) )                        as UnexplainedAbsolute,
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
  key Pos.CompanyCode                                       as CompanyCode,
  key Pos.Currency                                          as Currency,
      cast( 0 as abap.dec( 23, 2 ) )                        as RequestedAmount,
      cast( 0 as abap.dec( 23, 2 ) )                        as PaidAmount,
      cast( 0 as abap.dec( 23, 2 ) )                        as ClearedAmount,
      cast( case when Pos.EvalStatus = 'E' and Pos.EvalCategory = 'TRANSIT'
                 then abs( Pos.AccountedAmount ) else 0 end as abap.dec( 23, 2 ) ) as InTransitAmount,
      cast( case when Pos.EvalStatus = 'E' and Pos.EvalCategory = 'CLARIFY'
                 then abs( Pos.AccountedAmount ) else 0 end as abap.dec( 23, 2 ) ) as InClarificationAmount,
      cast( case when Pos.EvalStatus = 'E' and Pos.EvalCategory = 'CLARIFY'
                 then Pos.AccountedItems else 0 end as abap.int4 ) as InClarificationItems,
      cast( case when Pos.EvalStatus = 'E'
                 then abs( Pos.UnexplainedAmount ) else 0 end as abap.dec( 23, 2 ) ) as UnexplainedAbsolute,
      cast( case when Pos.EvalStatus = 'N' then 1 else 0 end as abap.int4 ) as NotEvaluatedCount
}

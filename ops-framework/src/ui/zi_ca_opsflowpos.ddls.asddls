// Artifact: zi_ca_opsflowpos.ddls.asddls
// Purpose: Account flow reconciliation - position of each account and currency: opening (balance before "from"),
//          journal movement of the window, closing = opening + journal movement (the books at "to"), what existing
//          checks account for at "to" (signed amounts as they are; an unsigned finding amount takes the sign of the
//          closing position) and Unexplained = closing - accounted for. Evaluation status: X no control point (role
//          OUTSIDE - shown, never evaluated), N not evaluated (no evaluation at "to", no source class, a source that
//          failed or could not say - Unexplained is not computed and shows grey, never as zero), E evaluated. Nothing
//          compared of its own: every figure is a posting or an open item of a check. Read-only.
// Modification log: 2026-11-15 | Initial version (build G: account flow reconciliation).
// VERIFY-ADT (V147): DEC arithmetic of sums in CASE (as the ledger model, V112), left outer join of a parameterised
//          view, COALESCE of an INT4 column.
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Account flow: positions and unexplained'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #M, dataClass: #TRANSACTIONAL }
define view entity ZI_CA_OpsFlowPos
  with parameters
    P_DateFrom : abap.dats,
    P_DateTo   : abap.dats
  as select from    ZI_CA_OpsFlowPosSum( P_DateFrom : $parameters.P_DateFrom,
                                         P_DateTo   : $parameters.P_DateTo ) as Ps
    inner join      ZI_CA_OpsFlowAcct                                        as Acc on  Acc.Area        = Ps.Area
                                                                                    and Acc.FlowId      = Ps.FlowId
                                                                                    and Acc.FlowAccount = Ps.FlowAccount
    left outer join ZI_CA_OpsFlowEvlAll( P_KeyDate : $parameters.P_DateTo )  as Al  on  Al.Area        = Ps.Area
                                                                                    and Al.FlowId      = Ps.FlowId
                                                                                    and Al.FlowAccount = Ps.FlowAccount
{
  key Ps.Area                                               as Area,
  key Ps.FlowId                                             as FlowId,
  key Ps.FlowAccount                                        as FlowAccount,
  key Ps.Currency                                           as Currency,
      Acc.AccountRole                                       as AccountRole,
      Acc.CompanyCode                                       as CompanyCode,
      Acc.EvalCategory                                      as EvalCategory,
      Ps.OpeningAmount                                      as OpeningAmount,
      Ps.GlMovement                                         as GlMovement,
      cast( Ps.OpeningAmount + Ps.GlMovement as abap.dec( 23, 2 ) ) as ClosingAmount,
      cast( case when Ps.OpeningAmount + Ps.GlMovement < 0
                 then Ps.SignedAmount - Ps.UnsignedAmount
                 else Ps.SignedAmount + Ps.UnsignedAmount end as abap.dec( 23, 2 ) ) as AccountedAmount,
      Ps.ItemCount                                          as AccountedItems,
      cast( case
              when Acc.AccountRole = 'OUTSIDE' then 'X'
              when Ps.NotEvaluatedCount > 0 or coalesce( Al.NotEvaluatedCount, 0 ) > 0 then 'N'
              when Ps.EvaluatedCount > 0 or coalesce( Al.EvaluatedCount, 0 ) > 0 then 'E'
              else 'N' end as zca_ops_flow_evst )           as EvalStatus,
      cast( case
              when Acc.AccountRole = 'OUTSIDE' then 0
              when Ps.NotEvaluatedCount > 0 or coalesce( Al.NotEvaluatedCount, 0 ) > 0 then 0
              when Ps.EvaluatedCount = 0 and coalesce( Al.EvaluatedCount, 0 ) = 0 then 0
              when Ps.OpeningAmount + Ps.GlMovement < 0
                then Ps.OpeningAmount + Ps.GlMovement - ( Ps.SignedAmount - Ps.UnsignedAmount )
              else Ps.OpeningAmount + Ps.GlMovement - ( Ps.SignedAmount + Ps.UnsignedAmount ) end
            as abap.dec( 23, 2 ) )                          as UnexplainedAmount
}

// Artifact: zi_ca_opsflowposu.ddls.asddls
// Purpose: Account flow reconciliation - the parts of each account's position per currency, one branch each (summed by
//          ZI_CA_OpsFlowPosSum, so an account with only an opening, only lines in the window or only an evaluation item
//          still has its row): the opening position before "from" (ZI_CA_OpsFlowOpen), every journal line of the
//          window (ZI_CA_OpsFlowGlSig - the books: for a subledger-posted account the G/L transfer and direct G/L
//          postings) and what the last evaluation at "to" accounts for (ZI_CA_OpsFlowEvlItm, rows of a currency).
//          Read-only.
// Modification log: 2026-11-15 | Initial version (build G: account flow reconciliation).
// VERIFY-ADT (V147): UNION ALL of three parameterised sources with typed literals (V112).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Account flow: position parts'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define view entity ZI_CA_OpsFlowPosU
  with parameters
    P_DateFrom : abap.dats,
    P_DateTo   : abap.dats
  as select from ZI_CA_OpsFlowOpen( P_DateFrom : $parameters.P_DateFrom ) as Op
{
  key Op.Area                                               as Area,
  key Op.FlowId                                             as FlowId,
  key Op.FlowAccount                                        as FlowAccount,
  key Op.Currency                                           as Currency,
      Op.OpeningAmount                                      as OpeningAmount,
      cast( 0 as abap.dec( 23, 2 ) )                        as GlMovement,
      cast( 0 as abap.dec( 23, 2 ) )                        as SignedAmount,
      cast( 0 as abap.dec( 23, 2 ) )                        as UnsignedAmount,
      cast( 0 as abap.int4 )                                as ItemCount,
      cast( 0 as abap.int4 )                                as EvaluatedCount,
      cast( 0 as abap.int4 )                                as NotEvaluatedCount
}
union all
  select from ZI_CA_OpsFlowGlSig( P_DateFrom : $parameters.P_DateFrom,
                                  P_DateTo   : $parameters.P_DateTo ) as Sig
{
  key Sig.Area                                              as Area,
  key Sig.FlowId                                            as FlowId,
  key Sig.FlowAccount                                       as FlowAccount,
  key Sig.Currency                                          as Currency,
      cast( 0 as abap.dec( 23, 2 ) )                        as OpeningAmount,
      Sig.Amount                                            as GlMovement,
      cast( 0 as abap.dec( 23, 2 ) )                        as SignedAmount,
      cast( 0 as abap.dec( 23, 2 ) )                        as UnsignedAmount,
      cast( 0 as abap.int4 )                                as ItemCount,
      cast( 0 as abap.int4 )                                as EvaluatedCount,
      cast( 0 as abap.int4 )                                as NotEvaluatedCount
}
union all
  select from ZI_CA_OpsFlowEvlItm( P_KeyDate : $parameters.P_DateTo ) as Itm
{
  key Itm.Area                                              as Area,
  key Itm.FlowId                                            as FlowId,
  key Itm.FlowAccount                                       as FlowAccount,
  key Itm.Currency                                          as Currency,
      cast( 0 as abap.dec( 23, 2 ) )                        as OpeningAmount,
      cast( 0 as abap.dec( 23, 2 ) )                        as GlMovement,
      Itm.SignedAmount                                      as SignedAmount,
      Itm.UnsignedAmount                                    as UnsignedAmount,
      Itm.ItemCount                                         as ItemCount,
      Itm.EvaluatedCount                                    as EvaluatedCount,
      Itm.NotEvaluatedCount                                 as NotEvaluatedCount
}
where
  Itm.Currency <> ''

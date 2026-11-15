// Artifact: zi_ca_opsflowpossum.ddls.asddls
// Purpose: Account flow reconciliation - the parts of ZI_CA_OpsFlowPosU summed per account and currency (opening,
//          journal movement of the window, what the evaluation accounts for signed / unsigned, its items and status
//          counts). Never across currencies. Read-only.
// Modification log: 2026-11-15 | Initial version (build G: account flow reconciliation).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Account flow: position sums'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #M, dataClass: #TRANSACTIONAL }
define view entity ZI_CA_OpsFlowPosSum
  with parameters
    P_DateFrom : abap.dats,
    P_DateTo   : abap.dats
  as select from ZI_CA_OpsFlowPosU( P_DateFrom : $parameters.P_DateFrom,
                                    P_DateTo   : $parameters.P_DateTo ) as Pu
{
  key Pu.Area                                               as Area,
  key Pu.FlowId                                             as FlowId,
  key Pu.FlowAccount                                        as FlowAccount,
  key Pu.Currency                                           as Currency,
      cast( sum( Pu.OpeningAmount ) as abap.dec( 23, 2 ) )  as OpeningAmount,
      cast( sum( Pu.GlMovement ) as abap.dec( 23, 2 ) )     as GlMovement,
      cast( sum( Pu.SignedAmount ) as abap.dec( 23, 2 ) )   as SignedAmount,
      cast( sum( Pu.UnsignedAmount ) as abap.dec( 23, 2 ) ) as UnsignedAmount,
      cast( sum( Pu.ItemCount ) as abap.int4 )              as ItemCount,
      cast( sum( Pu.EvaluatedCount ) as abap.int4 )         as EvaluatedCount,
      cast( sum( Pu.NotEvaluatedCount ) as abap.int4 )      as NotEvaluatedCount
}
group by
  Pu.Area,
  Pu.FlowId,
  Pu.FlowAccount,
  Pu.Currency

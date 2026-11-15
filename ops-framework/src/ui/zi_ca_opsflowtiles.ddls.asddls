// Artifact: zi_ca_opsflowtiles.ddls.asddls
// Purpose: Account flow reconciliation - the tile parts of ZI_CA_OpsFlowTileU summed per flow, company code and
//          currency (never across currencies). Read-only.
// Modification log: 2026-11-15 | Initial version (build G: account flow reconciliation).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Account flow: tile sums'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #S, dataClass: #TRANSACTIONAL }
define view entity ZI_CA_OpsFlowTileS
  with parameters
    P_DateFrom : abap.dats,
    P_DateTo   : abap.dats
  as select from ZI_CA_OpsFlowTileU( P_DateFrom : $parameters.P_DateFrom,
                                     P_DateTo   : $parameters.P_DateTo ) as Tu
{
  key Tu.Area                                               as Area,
  key Tu.FlowId                                             as FlowId,
  key Tu.CompanyCode                                        as CompanyCode,
  key Tu.Currency                                           as Currency,
      cast( sum( Tu.RequestedAmount ) as abap.dec( 23, 2 ) )       as RequestedAmount,
      cast( sum( Tu.PaidAmount ) as abap.dec( 23, 2 ) )            as PaidAmount,
      cast( sum( Tu.ClearedAmount ) as abap.dec( 23, 2 ) )         as ClearedAmount,
      cast( sum( Tu.InTransitAmount ) as abap.dec( 23, 2 ) )       as InTransitAmount,
      cast( sum( Tu.InClarificationAmount ) as abap.dec( 23, 2 ) ) as InClarificationAmount,
      cast( sum( Tu.InClarificationItems ) as abap.int4 )          as InClarificationItems,
      cast( sum( Tu.UnexplainedAbsolute ) as abap.dec( 23, 2 ) )   as UnexplainedAbsolute,
      cast( sum( Tu.NotEvaluatedCount ) as abap.int4 )             as NotEvaluatedCount
}
group by
  Tu.Area,
  Tu.FlowId,
  Tu.CompanyCode,
  Tu.Currency

// Artifact: zc_ca_opsflowtile.ddls.asddls
// Purpose: Account flow reconciliation - the tiles above the matrix (overview page KPI cards of service
//          ZUI_CA_OPS_FLOW), per flow, company code and currency for the posting date window: requested, paid /
//          settled by the bank, matched and cleared (from the stage rows), still in transit, in clarification (amount
//          and items), unexplained (absolute) and the exposure behind it = in transit + in clarification + unexplained,
//          the accounts not evaluated (exposure incomplete: grey, never green - ExposureCriticality 0). Read access:
//          DCL ZC_CA_OPSFLOWTILE (area, company code).
// Modification log: 2026-11-15 | Initial version (build G: account flow reconciliation).
// VERIFY-ADT (V147): a view entity with parameters exposed in an OData V4 service and read by overview page KPI cards
//          (parameters as the card's filter), criticality as INT1.
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Account flow tiles'
@Metadata.allowExtensions: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #S, dataClass: #TRANSACTIONAL }
define view entity ZC_CA_OpsFlowTile
  with parameters
    P_DateFrom : abap.dats,
    P_DateTo   : abap.dats
  as select from ZI_CA_OpsFlowTileS( P_DateFrom : $parameters.P_DateFrom,
                                     P_DateTo   : $parameters.P_DateTo ) as Ts
    inner join   zca_ops_flow                                            as Flw on  Flw.area    = Ts.Area
                                                                                and Flw.flow_id = Ts.FlowId
{
  key Ts.Area                                               as Area,
      @ObjectModel.text.element: [ 'FlowName' ]
  key Ts.FlowId                                             as FlowId,
  key Ts.CompanyCode                                        as CompanyCode,
  key Ts.Currency                                           as Currency,
      Flw.description                                       as FlowName,
      Flw.direction                                         as Direction,
      Ts.RequestedAmount                                    as RequestedAmount,
      Ts.PaidAmount                                         as PaidAmount,
      Ts.ClearedAmount                                      as ClearedAmount,
      Ts.InTransitAmount                                    as InTransitAmount,
      Ts.InClarificationAmount                              as InClarificationAmount,
      Ts.InClarificationItems                               as InClarificationItems,
      Ts.UnexplainedAbsolute                                as UnexplainedAbsolute,
      cast( Ts.InTransitAmount + Ts.InClarificationAmount + Ts.UnexplainedAbsolute
            as abap.dec( 23, 2 ) )                          as ExposureAmount,
      Ts.NotEvaluatedCount                                  as NotEvaluatedCount,
      cast( case when Ts.NotEvaluatedCount > 0 then 0
                 when Ts.UnexplainedAbsolute > 0 then 1
                 when Ts.InTransitAmount + Ts.InClarificationAmount > 0 then 2
                 else 3 end as abap.int1 )                  as ExposureCriticality
}

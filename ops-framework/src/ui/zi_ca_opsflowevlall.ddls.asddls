// Artifact: zi_ca_opsflowevlall.ddls.asddls
// Purpose: Account flow reconciliation - the evaluation items without a currency (an account of every currency: the
//          source's answer for every currency it has no row for - evaluated with nothing open, or not evaluated with
//          the reason), counted per account of the last evaluation at P_KeyDate. Read-only.
// Modification log: 2026-11-15 | Initial version (build G: account flow reconciliation).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Account flow: evaluation of every currency'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #M, dataClass: #TRANSACTIONAL }
define view entity ZI_CA_OpsFlowEvlAll
  with parameters
    P_KeyDate : abap.dats
  as select from ZI_CA_OpsFlowEvlItm( P_KeyDate : $parameters.P_KeyDate ) as Itm
{
  key Itm.Area                                              as Area,
  key Itm.FlowId                                            as FlowId,
  key Itm.FlowAccount                                       as FlowAccount,
      cast( sum( Itm.EvaluatedCount ) as abap.int4 )        as EvaluatedCount,
      cast( sum( Itm.NotEvaluatedCount ) as abap.int4 )     as NotEvaluatedCount
}
where
  Itm.Currency = ''
group by
  Itm.Area,
  Itm.FlowId,
  Itm.FlowAccount

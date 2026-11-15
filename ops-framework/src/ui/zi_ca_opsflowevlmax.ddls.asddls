// Artifact: zi_ca_opsflowevlmax.ddls.asddls
// Purpose: Account flow reconciliation - the last evaluation of a flow at each key date (report ZCA_OPS_FLOW_RUN may
//          run several times a day): the latest start per area, flow and key date of ZCA_OPS_FLWEVL (index FLW).
//          Read-only.
// Modification log: 2026-11-15 | Initial version (build G: account flow reconciliation).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Account flow: last evaluation per date'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_CA_OpsFlowEvlMax
  as select from zca_ops_flwevl as Evl
{
  key Evl.area                                              as Area,
  key Evl.flow_id                                           as FlowId,
  key Evl.key_date                                          as KeyDate,
      max( Evl.started_at )                                 as LastStart
}
group by
  Evl.area,
  Evl.flow_id,
  Evl.key_date

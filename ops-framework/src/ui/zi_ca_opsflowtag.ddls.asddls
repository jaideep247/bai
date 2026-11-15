// Artifact: zi_ca_opsflowtag.ddls.asddls
// Purpose: Account flow reconciliation - control tag of a stage per company code from its checks
//          (ZI_CA_OpsFlowCtl): O open - n open exceptions of its checks; P pending - a check without a current result;
//          R reconciled - every check has a current result and nothing open. A stage without a check has no row here:
//          the cube shows N (no control). Derived each time it is shown, nothing stored. Read-only.
// Modification log: 2026-11-15 | Initial version (build G: account flow reconciliation).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Account flow: control tag of a stage'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #S, dataClass: #MIXED }
define view entity ZI_CA_OpsFlowTag
  as select from ZI_CA_OpsFlowCtl as Ctl
{
  key Ctl.Area                                              as Area,
  key Ctl.FlowId                                            as FlowId,
  key Ctl.StageId                                           as StageId,
  key Ctl.CompanyCode                                       as CompanyCode,
      cast( sum( Ctl.OpenExceptions ) as abap.int4 )        as OpenExceptions,
      cast( sum( case when Ctl.IsPending = 'X' then 1 else 0 end ) as abap.int4 ) as PendingChecks,
      cast( count( * ) as abap.int4 )                       as CheckCount
}
group by
  Ctl.Area,
  Ctl.FlowId,
  Ctl.StageId,
  Ctl.CompanyCode

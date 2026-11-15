// Artifact: zi_ca_opsflowstgtag.ddls.asddls
// Purpose: Account flow reconciliation - every active stage of every active flow per company code of its accounts
//          with the control tag of its checks (ZI_CA_OpsFlowTag): R reconciled, O open, P pending, N no control (no check
//          configured - never shown as reconciled), the open exceptions and the number of checks. Source of the list
//          card ZC_CA_OpsFlowStage. Derived now, nothing stored. Read-only.
// Modification log: 2026-11-15 | Initial version (build G: account flow reconciliation).
// VERIFY-ADT (V147): SELECT DISTINCT with a left outer join (one row per stage and company code).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Account flow: stage control tags'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #S, dataClass: #MIXED }
define view entity ZI_CA_OpsFlowStgTag
  as select distinct from zca_ops_flwstg    as Stg
    inner join            ZI_CA_OpsFlowAcct as Acc on  Acc.Area   = Stg.area
                                                   and Acc.FlowId = Stg.flow_id
    left outer join       ZI_CA_OpsFlowTag  as Tag on  Tag.Area        = Stg.area
                                                   and Tag.FlowId      = Stg.flow_id
                                                   and Tag.StageId     = Stg.stage_id
                                                   and Tag.CompanyCode = Acc.CompanyCode
{
  key Stg.area                                              as Area,
  key Stg.flow_id                                           as FlowId,
  key Stg.stage_id                                          as StageId,
  key Acc.CompanyCode                                       as CompanyCode,
      Acc.FlowName                                          as FlowName,
      Stg.description                                       as StageName,
      Stg.seq                                               as StageOrder,
      cast( case
              when Tag.CheckCount is null then 'N'
              when Tag.OpenExceptions > 0 then 'O'
              when Tag.PendingChecks > 0 then 'P'
              else 'R' end as zca_ops_flow_tag )            as ControlStatus,
      cast( coalesce( Tag.OpenExceptions, 0 ) as abap.int4 ) as OpenExceptions,
      cast( coalesce( Tag.CheckCount, 0 ) as abap.int4 )    as CheckCount
}
where
  Stg.active = 'X'

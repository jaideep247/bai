// Artifact: zi_ca_opsflowctl.ddls.asddls
// Purpose: Account flow reconciliation - the latest result of each check that controls a stage (ZCA_OPS_FLWCTL), per
//          company code of the flow's accounts: its open exceptions now (open or assigned, severity B / E / W - the
//          area dashboard's ZI_CA_OpsChkOpen) of the company code and of the area level, and whether a current result
//          exists - a check of the registry (ZCA_OPS_CHECK) is pending while its latest run is stale or missing
//          (ZR_CA_OpsCheckStatus, CHECK_STALE_MIN_<area>); a check of a consumer's own engine (not in the registry)
//          shows no run the framework can see: pending unless it has open exceptions. Nothing stored. Read-only.
// Modification log: 2026-11-15 | Initial version (build G: account flow reconciliation).
// VERIFY-ADT (V147): CHAR 35 = CHAR 20 in an ON condition (as V125), a root view entity as a join source.
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Account flow: stage check results'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #S, dataClass: #MIXED }
define view entity ZI_CA_OpsFlowCtl
  as select distinct from zca_ops_flwctl        as Ctl
    inner join            ZI_CA_OpsFlowAcct     as Acc  on  Acc.Area   = Ctl.area
                                                        and Acc.FlowId = Ctl.flow_id
    left outer join       ZI_CA_OpsChkOpen      as OpB  on  OpB.Area        = Ctl.check_area
                                                        and OpB.CheckId     = Ctl.check_id
                                                        and OpB.CompanyCode = Acc.CompanyCode
    left outer join       ZI_CA_OpsChkOpen      as OpA  on  OpA.Area        = Ctl.check_area
                                                        and OpA.CheckId     = Ctl.check_id
                                                        and OpA.CompanyCode = ''
    left outer join       ZR_CA_OpsCheckStatus  as St   on  St.Area         = Ctl.check_area
                                                        and St.CheckId      = Ctl.check_id
                                                        and St.CompanyCode  = ''
{
  key Ctl.area                                              as Area,
  key Ctl.flow_id                                           as FlowId,
  key Ctl.stage_id                                          as StageId,
  key Acc.CompanyCode                                       as CompanyCode,
  key Ctl.check_area                                        as CheckArea,
  key Ctl.check_id                                          as CheckId,
      cast( coalesce( OpB.OpenExceptions, 0 ) + coalesce( OpA.OpenExceptions, 0 ) as abap.int4 ) as OpenExceptions,
      cast( case when St.CheckId is null then 'X'
                 when St.IsStale = 'X' then 'X'
                 else ' ' end as abap_boolean )             as IsPending,
      cast( case when St.CheckId is null then ' ' else 'X' end as abap_boolean ) as IsRegistered,
      St.LastRunAt                                          as LastRunAt
}
where
  Ctl.active = 'X'

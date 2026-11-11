// Artifact: zi_ca_opsprockpi.ddls.asddls
// Purpose: KPI rows of the active business processes (2026-11-11, dashboard filled from the activation): one
//          row per check slice of the area dashboard (ZR_CA_OpsCheckStatus - checks in effect only, per area,
//          check and company code) with its process, plus one empty area-level row per business process in
//          effect today (ZI_CA_OpsProcEff), so that an active process without a check in effect still shows
//          (zero checks). Summed per process and company code by ZI_CA_OpsProcAgg. Nothing stored, read-only.
// Modification log: 2026-11-11 | Initial version (process catalogue with activation).
// VERIFY-ADT: UNION ALL of a root view entity and a view entity with literal casts (7.58).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Active processes: KPI rows'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #M, dataClass: #MIXED }
define view entity ZI_CA_OpsProcKpi
  as select from ZR_CA_OpsCheckStatus as St
{
  key St.Area                                               as Area,
  key St.ProcessId                                          as ProcessId,
  key St.CompanyCode                                        as CompanyCode,
  key St.CheckId                                            as CheckId,
      St.CheckCount                                         as CheckCount,
      St.FlaggedCount                                       as FlaggedCount,
      St.StaleCount                                         as StaleCount,
      St.OpenExceptions                                     as OpenExceptions,
      cast( St.StatusCriticality as abap.int4 )             as StatusCriticality
}
where
  St.ProcessId <> ' '

union all

select from ZI_CA_OpsProcEff as Pe
{
  key Pe.Area                                               as Area,
  key Pe.ProcessId                                          as ProcessId,
  key cast( ' ' as bukrs )                                  as CompanyCode,
  key cast( ' ' as abap.char( 20 ) )                        as CheckId,
      cast( 0 as abap.int4 )                                as CheckCount,
      cast( 0 as abap.int4 )                                as FlaggedCount,
      cast( 0 as abap.int4 )                                as StaleCount,
      cast( 0 as abap.int4 )                                as OpenExceptions,
      cast( 3 as abap.int4 )                                as StatusCriticality
}
where
  Pe.IsActive = 'X'

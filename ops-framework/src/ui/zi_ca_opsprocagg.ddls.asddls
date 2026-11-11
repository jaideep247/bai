// Artifact: zi_ca_opsprocagg.ddls.asddls
// Purpose: KPIs per active business process and company-code slice (2026-11-11): checks in effect, checks with
//          an open exception, stale checks, open exceptions and the worst status criticality (1 action
//          required, 2 watch, 3 healthy) of the process's check slices (ZI_CA_OpsProcKpi). A company-code slice
//          sums its own company code only (docs/auth_zca_ops.md section 3c). Nothing stored, read-only.
// Modification log: 2026-11-11 | Initial version (process catalogue with activation).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Active processes: KPIs per slice'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #M, dataClass: #MIXED }
define view entity ZI_CA_OpsProcAgg
  as select from ZI_CA_OpsProcKpi as K
{
  key K.Area                                                as Area,
  key K.ProcessId                                           as ProcessId,
  key K.CompanyCode                                         as CompanyCode,
      cast( sum( K.CheckCount ) as abap.int4 )              as CheckCount,
      cast( sum( K.FlaggedCount ) as abap.int4 )            as FlaggedCount,
      cast( sum( K.StaleCount ) as abap.int4 )              as StaleCount,
      cast( sum( K.OpenExceptions ) as abap.int4 )          as OpenExceptions,
      min( K.StatusCriticality )                            as StatusCriticality
}
group by
  K.Area,
  K.ProcessId,
  K.CompanyCode

// Artifact: zi_cd_hckopenslice.ddls.asddls
// Purpose: Slices of the morning report KPI (company-code isolation, 2026-11-10): always the area-level slice
//          (blank company code - the as-of run and the open exceptions without company code), and one slice
//          per company code with open health check exceptions (ZI_CD_HckOpenSum). Keys only. Read-only.
// Modification log: 2026-11-10 | Initial version (company-code isolation of the health check dashboard).
// VERIFY-ADT: UNION (distinct) whose first branch reads the one-row as-of view only for its literal key (7.58).
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'HCK KPI slices per company code'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #S, dataClass: #MIXED }
@VDM.viewType: #COMPOSITE
define view entity ZI_CD_HckOpenSlice
  as select from ZR_CD_HckAsOf as AsOf
{
  key cast( ' ' as bukrs )                                  as CompanyCode
}

union

select from ZI_CD_HckOpenSum as OpenSum
{
  key OpenSum.CompanyCode                                   as CompanyCode
}
where
  OpenSum.CompanyCode <> ' '

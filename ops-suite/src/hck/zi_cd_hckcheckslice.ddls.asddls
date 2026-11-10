// Artifact: zi_cd_hckcheckslice.ddls.asddls
// Purpose: Slices of a health check (company-code isolation, 2026-11-10): the area-level slice (blank company
//          code) of every active check, and one slice per company code with open exceptions of the check
//          (ZI_CD_HckCheckOpen). The check list, the red / amber card and the categories show one row per
//          slice: the verdict counters (checks red / amber / green, metrics) only on the area-level slice, the
//          open exceptions of each company code on its own slice - so the DCL on the slice's company code
//          filters the exceptions before a card or the analytical list sums them. Keys only. Read-only.
// Modification log: 2026-11-10 | Initial version (company-code isolation of the health check dashboard).
// VERIFY-ADT: UNION (distinct) with identical key elements and the cast of a literal to BUKRS (7.58).
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'HCK check slices per company code'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #S, dataClass: #MIXED }
@VDM.viewType: #COMPOSITE
define view entity ZI_CD_HckCheckSlice
  as select from zcd_hck_def as Def
{
  key Def.check_id                                          as CheckId,
  key cast( ' ' as bukrs )                                  as CompanyCode
}
where
  Def.active = 'X'

union

select from  ZI_CD_HckCheckOpen as OpenExc
  inner join zcd_hck_def        as Def on Def.check_id = OpenExc.CheckId
{
  key OpenExc.CheckId                                       as CheckId,
  key OpenExc.CompanyCode                                   as CompanyCode
}
where
      Def.active          =  'X'
  and OpenExc.CompanyCode <> ' '

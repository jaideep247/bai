// Artifact: zi_cd_ebsrunslice.ddls.asddls
// Purpose: Slices of an EBS validation run (company-code isolation, 2026-11-10): the area-level slice (blank
//          company code) of every run of the window, and one slice per company code that has findings of the
//          run (ZI_CD_EbsRunFind). The run list and the KPI show one row per slice: the run's own counters
//          (lines validated, passed, failed - area-level, a run has no company code) only on the area-level
//          slice, the finding counts of each company code on its own slice - so the DCL on the slice's
//          company code filters the findings before the analytical list sums them. Keys only. Read-only.
// Modification log: 2026-11-10 | Initial version (company-code isolation of the EBS validation dashboard).
// VERIFY-ADT: UNION (distinct) with identical key elements and the cast of a literal to BUKRS (7.58).
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'EBS run slices per company code'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #M, dataClass: #TRANSACTIONAL }
@VDM.viewType: #COMPOSITE
define view entity ZI_CD_EbsRunSlice
  as select from ZI_CD_EbsRunBase as Run
{
  key Run.RunId                                             as RunId,
  key cast( ' ' as bukrs )                                  as CompanyCode
}

union

select from  ZI_CD_EbsRunFind as Find
  inner join ZI_CD_EbsRunBase as Run on Run.RunId = Find.RunId
{
  key Find.RunId                                            as RunId,
  key Find.CompanyCode                                      as CompanyCode
}
where
  Find.CompanyCode <> ' '

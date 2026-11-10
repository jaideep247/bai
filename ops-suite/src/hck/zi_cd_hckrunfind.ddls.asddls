// Artifact: zi_cd_hckrunfind.ddls.asddls
// Purpose: Findings of each morning report run per company code (ZI_CD_HckFinding: open, or created in the last
//          31 days - the window of the run list) - the finding count of a run slice (company-code isolation,
//          2026-11-10; replaces the run header's FINDING_COUNT, which counts every company code). Read-only.
// Modification log: 2026-11-10 | Initial version (company-code isolation of the health check dashboard).
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'HCK findings per run and company code'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #M, dataClass: #TRANSACTIONAL }
@VDM.viewType: #COMPOSITE
define view entity ZI_CD_HckRunFind
  as select from ZI_CD_HckFinding
{
  key RunId,
  key CompanyCode,
      cast( count( * ) as abap.int4 )                       as FindingCount
}
group by
  RunId,
  CompanyCode

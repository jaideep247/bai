// Artifact: zi_cd_hckrunslice.ddls.asddls
// Purpose: Slices of a morning report run of the last 31 days (company-code isolation, 2026-11-10): the
//          area-level slice (blank company code) of every non-test run, and one slice per company code with
//          findings of the run (ZI_CD_HckRunFind). The run list carries the run's check counters on the
//          area-level slice only and the findings of each company code on its own slice. Keys only. Read-only.
// Modification log: 2026-11-10 | Initial version (company-code isolation of the health check dashboard).
// VERIFY-ADT: UNION (distinct) with identical key elements and the cast of a literal to BUKRS (7.58).
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'HCK run slices per company code'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #M, dataClass: #TRANSACTIONAL }
@VDM.viewType: #COMPOSITE
define view entity ZI_CD_HckRunSlice
  as select from zca_ops_run as Run
{
  key Run.run_id                                            as RunId,
  key cast( ' ' as bukrs )                                  as CompanyCode
}
where
      Run.area      = 'CD_HCK'
  and Run.test_mode = ' '
  and tstmp_to_dats( cast( Run.started_at as timestamp ), 'UTC', $session.client, 'NULL' )
      >= dats_add_days( $session.system_date, -31, 'INITIAL' )

union

select from  ZI_CD_HckRunFind as Find
  inner join zca_ops_run      as Run on Run.run_id = Find.RunId
{
  key Find.RunId                                            as RunId,
  key Find.CompanyCode                                      as CompanyCode
}
where
      Find.CompanyCode <> ' '
  and Run.area       =  'CD_HCK'
  and Run.test_mode  =  ' '
  and tstmp_to_dats( cast( Run.started_at as timestamp ), 'UTC', $session.client, 'NULL' )
      >= dats_add_days( $session.system_date, -31, 'INITIAL' )

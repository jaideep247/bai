// Artifact: zi_cd_opsfreshu.ddls.asddls
// Purpose: Monitor freshness per payment engine area for the production-support overview page
//          (docs/Dashboard_Production_Support.md): the "as of" rows of the three batch monitors in
//          one shape - FMON (ZR_CD_FmonAsOf: last completed full run, stale after 45 minutes),
//          EBS (ZR_CD_EbsAsOf: 26 hours), HCK (ZR_CD_HckAsOf: 26 hours) - with the threshold each
//          applies. The transactions dashboard is live (no monitor run) and has no row. Read-only.
// Modification log: 2026-11-06 | Initial version (production-support overview page).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Monitor freshness per area (union)'
@Metadata.ignorePropagatedAnnotations: true
// VERIFY-ADT: UNION of three one-row root views (as ZI_CD_HckCfgChg)
define view entity ZI_CD_OpsFreshU
  as select from ZR_CD_FmonAsOf
{
  key PaymentEngineArea                                     as PaymentEngineArea,
      cast( 'File monitoring' as abap.char( 30 ) )          as AreaText,
      RunId                                                 as RunId,
      AsOfAt                                                as AsOfAt,
      RunStatus                                             as RunStatus,
      AgeMinutes                                            as AgeMinutes,
      cast( 45 as abap.int4 )                               as StaleAfterMinutes,
      IsStale                                               as IsStale,
      StaleCriticality                                      as StaleCriticality
}
union all
  select from ZR_CD_EbsAsOf
{
  key PaymentEngineArea                                     as PaymentEngineArea,
      cast( 'EBS validation' as abap.char( 30 ) )           as AreaText,
      RunId                                                 as RunId,
      AsOfAt                                                as AsOfAt,
      RunStatus                                             as RunStatus,
      AgeMinutes                                            as AgeMinutes,
      StaleAfterMinutes                                     as StaleAfterMinutes,
      IsStale                                               as IsStale,
      StaleCriticality                                      as StaleCriticality
}
union all
  select from ZR_CD_HckAsOf
{
  key PaymentEngineArea                                     as PaymentEngineArea,
      cast( 'Morning report / health checks' as abap.char( 30 ) ) as AreaText,
      RunId                                                 as RunId,
      AsOfAt                                                as AsOfAt,
      RunStatus                                             as RunStatus,
      AgeMinutes                                            as AgeMinutes,
      StaleAfterMinutes                                     as StaleAfterMinutes,
      IsStale                                               as IsStale,
      StaleCriticality                                      as StaleCriticality
}

// Artifact: zi_cd_opsfreshu.ddls.asddls
// Purpose: Monitor freshness per payment engine area for the production-support overview page
//          (docs/Dashboard_Production_Support.md): the "as of" rows of the three batch monitors in
//          one shape - FMON (ZR_CD_FmonAsOf: last completed full run), EBS (ZR_CD_EbsAsOf), HCK
//          (ZR_CD_HckAsOf) - with the threshold each applies (ZCA_PARAM MON_STALE_AFTER_MIN_<area>, else 15 min / 26 h). The transactions dashboard is live (no monitor run) and has no row. Read-only.
// Modification log: 2026-11-06 | Initial version (production-support overview page).
//                   2026-11-06 | FMON threshold 15 min (native SAP job every 5 min).
//                   2026-11-07 | Thresholds from the as-of views (ZCD_OPS_MONCFG), no literal here.
//                   2026-11-08 | Table consolidation: the as-of views read ZCA_PARAM (ZI_CD_OpsStaleCfg).
//                   2026-11-08 | Fourth row CORE: the payment outcome snapshot lag (ZI_CD_PayOutLag - minutes
//                                behind the evidence, stale after MON_STALE_AFTER_MIN_CORE, default 30).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Monitor freshness per area (union)'
@Metadata.ignorePropagatedAnnotations: true
// VERIFY-ADT: UNION of three one-row root views and the one-row snapshot lag (as ZI_CD_HckCfgChg)
define view entity ZI_CD_OpsFreshU
  as select from ZR_CD_FmonAsOf
{
  key PaymentEngineArea                                     as PaymentEngineArea,
      cast( 'File monitoring' as abap.char( 30 ) )          as AreaText,
      RunId                                                 as RunId,
      AsOfAt                                                as AsOfAt,
      RunStatus                                             as RunStatus,
      AgeMinutes                                            as AgeMinutes,
      StaleAfterMinutes                                     as StaleAfterMinutes,
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
union all
  select from ZI_CD_PayOutLag
{
  key PaymentEngineArea                                     as PaymentEngineArea,
      cast( 'Payment outcome snapshot lag' as abap.char( 30 ) ) as AreaText,
      RunId                                                 as RunId,
      AsOfAt                                                as AsOfAt,
      RunStatus                                             as RunStatus,
      AgeMinutes                                            as AgeMinutes,
      StaleAfterMinutes                                     as StaleAfterMinutes,
      IsStale                                               as IsStale,
      StaleCriticality                                      as StaleCriticality
}

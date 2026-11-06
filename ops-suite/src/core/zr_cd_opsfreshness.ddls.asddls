// Artifact: zr_cd_opsfreshness.ddls.asddls
// Purpose: "Monitor freshness" card of the production-support overview page: one row per batch
//          monitor area (FMON, EBS, HCK) with the end of its last completed run, age, threshold
//          and stale flag, plus a count measure for the stale tile. A monitor that stopped shows
//          red here before anyone reads its dashboard. Read-only.
// Modification log: 2026-11-06 | Initial version (production-support overview page).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Production support - monitor freshness'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #S, dataClass: #MIXED }
define root view entity ZR_CD_OpsFreshness
  as select from ZI_CD_OpsFreshU
{
  key PaymentEngineArea,
      AreaText,
      RunId,
      AsOfAt,
      RunStatus,
      AgeMinutes,
      StaleAfterMinutes,
      IsStale,
      StaleCriticality,
      cast( case IsStale when 'X' then 1 else 0 end as abap.int4 ) as StaleMonitorCount
}

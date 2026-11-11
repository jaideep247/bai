// Artifact: zi_cd_svcstale.ddls.asddls
// Purpose: Service health - stale monitors of a business service now: the areas its rules read (ZI_CD_SvcRule) whose
//          monitor is stale (ZR_CD_OpsFreshness, MON_STALE_AFTER_MIN_<area>), with the stale points of the service.
//          A stale monitor means the findings are not fresh - the score must not look healthy. Applied to the current
//          business date only (freshness is now, not history). Area-level. Read-only.
// Modification log: 2026-11-11 | Initial version (service health score of the overview page).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Service health - stale monitors'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #S, dataClass: #TRANSACTIONAL }
define view entity ZI_CD_SvcStale
  as select distinct from ZI_CD_SvcRule      as Rule
    inner join            ZR_CD_OpsFreshness as Fresh on  Fresh.PaymentEngineArea = Rule.CheckArea
                                                      and Fresh.IsStale           = 'X'
    inner join            zcd_ops_svc        as Svc   on  Svc.service             = Rule.Service
{
  key Rule.Service,
  key Rule.CheckArea                                        as Area,
      Svc.stale_points                                      as StalePoints
}

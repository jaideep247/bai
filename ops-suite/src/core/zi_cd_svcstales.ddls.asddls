// Artifact: zi_cd_svcstales.ddls.asddls
// Purpose: Service health - stale monitors per business service now (ZI_CD_SvcStale): their number and points.
// Modification log: 2026-11-11 | Initial version (service health score of the overview page).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Service health - stale points per service'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #S, dataClass: #TRANSACTIONAL }
define view entity ZI_CD_SvcStaleS
  as select from ZI_CD_SvcStale
{
  key Service,
      cast( sum( StalePoints ) as abap.int4 )               as StalePoints,
      cast( count( * ) as abap.int4 )                       as StaleMonitors
}
group by
  Service

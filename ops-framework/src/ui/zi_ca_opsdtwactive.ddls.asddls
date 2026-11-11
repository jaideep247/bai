// Artifact: zi_ca_opsdtwactive.ddls.asddls
// Purpose: Active planned downtime per area now (ZI_CA_OpsDtwNow: approved, started, not ended): the number of
//          active windows and of area-wide ones (no scope pattern - they also hold back the run-level alerts).
//          The mark of the area dashboard (area-level slice). Counted on the database, nothing stored. Read-only.
// Modification log: 2026-11-11 | Initial version (operations response features: planned downtime).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Active planned downtime per area'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #S, dataClass: #TRANSACTIONAL }
define view entity ZI_CA_OpsDtwActive
  as select from ZI_CA_OpsDtwNow
{
  key Area,
      cast( count( * ) as abap.int4 )                       as ActiveWindows,
      cast( sum( case IsAreaWide when 'X' then 1 else 0 end ) as abap.int4 ) as AreaWideWindows
}
where
  IsActive = 'X'
group by
  Area

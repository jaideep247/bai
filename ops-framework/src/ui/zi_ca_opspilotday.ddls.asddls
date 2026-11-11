// Artifact: zi_ca_opspilotday.ddls.asddls
// Purpose: Pilot pack - one row per day of the raise, area, business process and check (export ZCA_OPS_PILOT_EXPORT):
//          raised, assigned, resolved, false positives, detections measurable, detected earlier than the baseline,
//          and the summed minutes to detect / to assign / to resolve and the baseline (the export divides them by
//          their counts - an average of averages is never taken). Company codes are summed: the export is an
//          area-level figure (its user needs ZCA_OPS 03 for the area). Aggregated on the database, read-only.
// Modification log: 2026-11-11 | Initial version (build F: pilot pack).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Pilot pack: metrics per day'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #M, dataClass: #TRANSACTIONAL }
define view entity ZI_CA_OpsPilotDay
  as select from ZR_CA_OpsPilot
{
  key RaisedDate,
  key Area,
  key ProcessId,
  key CheckId,
      cast( sum( RaisedCount ) as abap.int4 )               as RaisedCount,
      cast( sum( AssignedCount ) as abap.int4 )             as AssignedCount,
      cast( sum( ResolvedCount ) as abap.int4 )             as ResolvedCount,
      cast( sum( FalsePositiveCount ) as abap.int4 )        as FalsePositiveCount,
      cast( sum( DetectKnownCount ) as abap.int4 )          as DetectKnownCount,
      cast( sum( BaselineKnownCount ) as abap.int4 )        as BaselineKnownCount,
      cast( sum( EarlierCount ) as abap.int4 )              as EarlierCount,
      cast( sum( MinutesToDetect ) as abap.dec( 23, 1 ) )   as MinutesToDetect,
      cast( sum( BaselineMinutes ) as abap.dec( 23, 1 ) )   as BaselineMinutes,
      cast( sum( MinutesToAssign ) as abap.dec( 23, 1 ) )   as MinutesToAssign,
      cast( sum( MinutesToResolve ) as abap.dec( 23, 1 ) )  as MinutesToResolve
}
group by
  RaisedDate,
  Area,
  ProcessId,
  CheckId

@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Pilot detection baselines'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CA_PilotBaseline
  as select from zca_ops_pilotbl
  association to parent ZR_CA_OpsCfgAll as _OpsCfgAll on $projection.SingletonID = _OpsCfgAll.SingletonID
{
      @EndUserText.label: 'Area (alert rules: * = every area)'
  key area as Area,
      @EndUserText.label: 'Check ID'
  key check_id as CheckId,
      1 as SingletonID,
      @EndUserText.label: 'Previous detection time (minutes after the event)'
      baseline_min as BaselineMin,
      @EndUserText.label: 'Source of the baseline'
      source as Source,
      @EndUserText.label: 'Description'
      description as Description,
      @Semantics.user.lastChangedBy: true
      @EndUserText.label: 'Last changed by'
      last_changed_by as LastChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      @EndUserText.label: 'Last changed at'
      last_changed_at as LastChangedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      @EndUserText.label: 'Changed at (instance)'
      local_last_changed_at as LocalLastChangedAt,
      _OpsCfgAll
}

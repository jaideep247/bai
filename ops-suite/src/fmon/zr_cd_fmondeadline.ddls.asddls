@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Stage deadlines (clock time)'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CD_FmonDeadline
  as select from zcd_fmon_deadl
  association to parent ZR_CD_FmonCfgAll as _FmonCfgAll on $projection.SingletonID = _FmonCfgAll.SingletonID
{
      @EndUserText.label: 'Interface ID'
  key iface_id as IfaceId,
      @EndUserText.label: 'Stage'
  key stage as Stage,
      @EndUserText.label: 'Day type'
  key day_type as DayType,
      1 as SingletonID,
      @EndUserText.label: 'Due time'
      due_time as DueTime,
      @EndUserText.label: 'Severity'
      severity as Severity,
      @EndUserText.label: 'Active'
      active as Active,
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
      _FmonCfgAll
}

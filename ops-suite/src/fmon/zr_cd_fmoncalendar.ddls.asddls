@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Expected files per day type'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CD_FmonCalendar
  as select from zcd_fmon_cal
  association to parent ZR_CD_FmonCfgAll as _FmonCfgAll on $projection.SingletonID = _FmonCfgAll.SingletonID
{
      @EndUserText.label: 'Interface ID'
  key iface_id as IfaceId,
      @EndUserText.label: 'Day type'
  key day_type as DayType,
      1 as SingletonID,
      @EndUserText.label: 'Expected count'
      expected_count as ExpectedCount,
      @EndUserText.label: 'Window from'
      window_from as WindowFrom,
      @EndUserText.label: 'Window to'
      window_to as WindowTo,
      @EndUserText.label: 'Factory calendar ID'
      fcal_id as FcalId,
      @EndUserText.label: 'Active'
      active as Active,
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

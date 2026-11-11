@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Controls (daily review)'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CA_Control
  as select from zca_ops_control
  association to parent ZR_CA_OpsCfgAll as _OpsCfgAll on $projection.SingletonID = _OpsCfgAll.SingletonID
{
      @EndUserText.label: 'Area (alert rules: * = every area)'
  key area as Area,
      @EndUserText.label: 'Control ID'
  key control_id as ControlId,
      1 as SingletonID,
      @EndUserText.label: 'Description'
      description as Description,
      @EndUserText.label: 'Category'
      category as Category,
      @EndUserText.label: 'Owner'
      owner as Owner,
      @EndUserText.label: 'Backup'
      backup as Backup,
      @EndUserText.label: 'Team (parameter CONTROL_TEAMS)'
      team as Team,
      @EndUserText.label: 'Review cut-off (local time, CONTROL_TIME_ZONE)'
      cutoff_time as CutoffTime,
      @EndUserText.label: 'Runbook URL'
      runbook_url as RunbookUrl,
      @EndUserText.label: 'Active'
      active as Active,
      @EndUserText.label: 'Display order'
      seq as Seq,
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

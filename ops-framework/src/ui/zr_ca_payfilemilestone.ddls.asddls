@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment file milestones'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CA_PayFileMilestone
  as select from zca_ops_pfstg
  association to parent ZR_CA_OpsCfgAll as _OpsCfgAll on $projection.SingletonID = _OpsCfgAll.SingletonID
{
      @EndUserText.label: 'Area (alert rules: * = every area)'
  key area as Area,
      @EndUserText.label: 'Payment file type'
  key file_type as FileType,
      @EndUserText.label: 'Milestone'
  key milestone as Milestone,
      1 as SingletonID,
      @EndUserText.label: 'Description'
      description as Description,
      @EndUserText.label: 'Required'
      required as Required,
      @EndUserText.label: 'Deadline (T clock time, O offset)'
      due_kind as DueKind,
      @EndUserText.label: 'Due at (local time)'
      due_time as DueTime,
      @EndUserText.label: 'Business days after the business date'
      day_offset as DayOffset,
      @EndUserText.label: 'Offset from milestone'
      basis as Basis,
      @EndUserText.label: 'Offset (minutes)'
      offset_min as OffsetMin,
      @EndUserText.label: 'Warning for (minutes, 0 = PF_GRACE_MIN)'
      grace_min as GraceMin,
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
      _OpsCfgAll
}

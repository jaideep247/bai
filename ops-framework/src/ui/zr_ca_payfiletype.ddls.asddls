@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment file types'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CA_PayFileType
  as select from zca_ops_pftyp
  association to parent ZR_CA_OpsCfgAll as _OpsCfgAll on $projection.SingletonID = _OpsCfgAll.SingletonID
{
      @EndUserText.label: 'Area (alert rules: * = every area)'
  key area as Area,
      @EndUserText.label: 'Payment file type'
  key file_type as FileType,
      1 as SingletonID,
      @EndUserText.label: 'Description'
      description as Description,
      @EndUserText.label: 'Business process'
      process_id as ProcessId,
      @EndUserText.label: 'Direction (D disbursement, C collection)'
      direction as Direction,
      @EndUserText.label: 'Bank ACK level (F file, B batch, P payment, N none)'
      ack_level as AckLevel,
      @EndUserText.label: 'One ACK may cover several files'
      ack_multi as AckMulti,
      @EndUserText.label: 'Factory calendar (SCAL)'
      calendar_id as CalendarId,
      @EndUserText.label: 'Time zone of the clock times'
      time_zone as TimeZone,
      @EndUserText.label: 'Overnight cut-off (local time)'
      day_cutoff as DayCutoff,
      @EndUserText.label: 'Files expected per business day'
      expected_files as ExpectedFiles,
      @EndUserText.label: 'A business day without files is valid'
      zero_ok as ZeroOk,
      @EndUserText.label: 'Source stale after (minutes, 0 = PF_STALE_MIN)'
      stale_min as StaleMin,
      @EndUserText.label: 'Watched for (days, 0 = PF_OPEN_DAYS)'
      open_days as OpenDays,
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

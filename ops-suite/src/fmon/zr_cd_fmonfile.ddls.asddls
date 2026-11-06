@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Monitored files - manual status'
@Metadata.ignorePropagatedAnnotations: true
// FMON manual status (design 6.4): files of the registry; only the manual-status action changes them
define root view entity ZR_CD_FmonFile
  as select from zcd_fmon_file
{
      @EndUserText.label: 'File ID'
  key file_id           as FileId,
      @EndUserText.label: 'Interface'
      iface_id          as IfaceId,
      @EndUserText.label: 'File reference'
      file_ref          as FileRef,
      @EndUserText.label: 'Direction'
      direction         as Direction,
      @EndUserText.label: 'File name'
      file_name         as FileName,
      @EndUserText.label: 'Business date'
      business_date     as BusinessDate,
      @EndUserText.label: 'Stage'
      stage             as Stage,
      @EndUserText.label: 'Outcome'
      outcome           as Outcome,
      @EndUserText.label: 'Unprocessed items'
      unprocessed_count as UnprocessedCount,
      @EndUserText.label: 'Records'
      record_count      as RecordCount,
      @EndUserText.label: 'Control total'
      control_total     as ControlTotal,
      @EndUserText.label: 'Last event'
      last_event_at     as LastEventAt,
      @EndUserText.label: 'Changed at'
      changed_at        as ChangedAt,
      @EndUserText.label: 'Changed by'
      changed_by        as ChangedBy
}

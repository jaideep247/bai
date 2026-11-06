@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Status mappings'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CD_FmonSourceMap
  as select from zcd_fmon_srcmap
  association to parent ZR_CD_FmonCfgAll as _FmonCfgAll on $projection.SingletonID = _FmonCfgAll.SingletonID
{
      @EndUserText.label: 'Source ID'
  key src_id as SrcId,
      @EndUserText.label: 'Status value'
  key status_value as StatusValue,
      1 as SingletonID,
      @EndUserText.label: 'Stage'
      stage as Stage,
      @EndUserText.label: 'Info'
      info as Info,
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

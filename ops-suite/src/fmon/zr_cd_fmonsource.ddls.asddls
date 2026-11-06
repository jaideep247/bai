@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Source adapters'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CD_FmonSource
  as select from zcd_fmon_src
  association to parent ZR_CD_FmonCfgAll as _FmonCfgAll on $projection.SingletonID = _FmonCfgAll.SingletonID
{
      @EndUserText.label: 'Source ID'
  key src_id as SrcId,
      1 as SingletonID,
      @EndUserText.label: 'Interface ID'
      iface_id as IfaceId,
      @EndUserText.label: 'Table name'
      table_name as TableName,
      @EndUserText.label: 'File key field'
      file_key_field as FileKeyField,
      @EndUserText.label: 'File name field'
      file_name_field as FileNameField,
      @EndUserText.label: 'Date field'
      date_field as DateField,
      @EndUserText.label: 'Time field'
      time_field as TimeField,
      @EndUserText.label: 'Timestamp field'
      ts_field as TsField,
      @EndUserText.label: 'Status field'
      status_field as StatusField,
      @EndUserText.label: 'Count field'
      count_field as CountField,
      @EndUserText.label: 'Amount field'
      amount_field as AmountField,
      @EndUserText.label: 'Size field'
      size_field as SizeField,
      @EndUserText.label: 'Checksum field'
      checksum_field as ChecksumField,
      @EndUserText.label: 'Source field'
      source_field as SourceField,
      @EndUserText.label: 'Line of business field'
      lob_field as LobField,
      @EndUserText.label: 'Item key field'
      item_key_field as ItemKeyField,
      @EndUserText.label: 'Default stage'
      default_stage as DefaultStage,
      @EndUserText.label: 'Adapter class'
      adapter_class as AdapterClass,
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

@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interfaces'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CD_FmonIface
  as select from zcd_fmon_iface
  association to parent ZR_CD_FmonCfgAll as _FmonCfgAll on $projection.SingletonID = _FmonCfgAll.SingletonID
{
      @EndUserText.label: 'Interface ID'
  key iface_id as IfaceId,
      1 as SingletonID,
      @EndUserText.label: 'Direction'
      direction as Direction,
      @EndUserText.label: 'File type'
      file_type as FileType,
      @EndUserText.label: 'Source sys'
      source_sys as SourceSys,
      @EndUserText.label: 'Target sys'
      target_sys as TargetSys,
      @EndUserText.label: 'Payment method'
      pay_method as PayMethod,
      @EndUserText.label: 'Line of business'
      lob as Lob,
      @EndUserText.label: 'Bank key (blank = all banks)'
      bank_key as BankKey,
      @EndUserText.label: 'Name pattern'
      name_pattern as NamePattern,
      @EndUserText.label: 'Minimum bytes'
      min_bytes as MinBytes,
      @EndUserText.label: 'Maximum bytes'
      max_bytes as MaxBytes,
      @EndUserText.label: 'Ack expected'
      ack_expected as AckExpected,
      @EndUserText.label: 'ACK level'
      ack_level as AckLevel,
      @EndUserText.label: 'Owner'
      owner as Owner,
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

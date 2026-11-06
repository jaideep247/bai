@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Lookups (rule R21)'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CD_EbsLookup
  as select from zcd_ebs_lookup
  association to parent ZR_CD_EbsCfgAll as _EbsCfgAll on $projection.SingletonID = _EbsCfgAll.SingletonID
{
      @EndUserText.label: 'Lookup ID'
  key lookup_id as LookupId,
      1 as SingletonID,
      @EndUserText.label: 'Table name'
      table_name as TableName,
      @EndUserText.label: 'Key field'
      key_field as KeyField,
      @EndUserText.label: 'Key kind'
      key_kind as KeyKind,
      @EndUserText.label: 'Key length'
      key_length as KeyLength,
      @EndUserText.label: 'Status field'
      status_field as StatusField,
      @EndUserText.label: 'Allowed values'
      allowed_values as AllowedValues,
      @EndUserText.label: 'Not found code'
      not_found_code as NotFoundCode,
      @EndUserText.label: 'Status code'
      status_code as StatusCode,
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
      _EbsCfgAll
}

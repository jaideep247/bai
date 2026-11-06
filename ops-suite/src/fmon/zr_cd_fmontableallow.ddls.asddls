@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Approved tables'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CD_FmonTableAllow
  as select from zcd_fmon_tabwl
  association to parent ZR_CD_FmonCfgAll as _FmonCfgAll on $projection.SingletonID = _FmonCfgAll.SingletonID
{
      @EndUserText.label: 'Table name'
  key table_name as TableName,
      @EndUserText.label: 'Field name'
  key field_name as FieldName,
      1 as SingletonID,
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

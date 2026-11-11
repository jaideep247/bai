@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Link registry business objects'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CA_LinkObject
  as select from zca_ops_lnkobj
  association to parent ZR_CA_OpsCfgAll as _OpsCfgAll on $projection.SingletonID = _OpsCfgAll.SingletonID
{
      @EndUserText.label: 'Business object'
  key object_id as ObjectId,
      1 as SingletonID,
      @EndUserText.label: 'Layer'
      layer_id as LayerId,
      @EndUserText.label: 'Table or CDS view'
      source_name as SourceName,
      @EndUserText.label: 'Source kind (T table, V view)'
      source_kind as SourceKind,
      @EndUserText.label: 'Key fields (finding fields, comma list)'
      key_fields as KeyFields,
      @EndUserText.label: 'Description'
      description as Description,
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

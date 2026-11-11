@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Link registry layers'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CA_LinkLayer
  as select from zca_ops_lnklyr
  association to parent ZR_CA_OpsCfgAll as _OpsCfgAll on $projection.SingletonID = _OpsCfgAll.SingletonID
{
      @EndUserText.label: 'Layer'
  key layer_id as LayerId,
      1 as SingletonID,
      @EndUserText.label: 'Kind (S baseline, I industry, C customer)'
      layer_kind as LayerKind,
      @EndUserText.label: 'Rank (higher extends lower)'
      layer_rank as LayerRank,
      @EndUserText.label: 'ID prefix of objects and links'
      id_prefix as IdPrefix,
      @EndUserText.label: 'Description'
      description as Description,
      @EndUserText.label: 'Owner'
      owner as Owner,
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

@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Link registry links'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CA_Link
  as select from zca_ops_link
  association to parent ZR_CA_OpsCfgAll as _OpsCfgAll on $projection.SingletonID = _OpsCfgAll.SingletonID
{
      @EndUserText.label: 'Link'
  key link_id as LinkId,
      1 as SingletonID,
      @EndUserText.label: 'Layer'
      layer_id as LayerId,
      @EndUserText.label: 'From object'
      from_object as FromObject,
      @EndUserText.label: 'To object'
      to_object as ToObject,
      @EndUserText.label: 'Cardinality (11, 1N, N1, NM)'
      cardinality as Cardinality,
      @EndUserText.label: 'Evidence quality (C, P)'
      quality as Quality,
      @EndUserText.label: 'Fallback of link'
      fallback_of as FallbackOf,
      @EndUserText.label: 'Replaces link'
      replaces as Replaces,
      @EndUserText.label: 'Active'
      active as Active,
      @EndUserText.label: 'Owner'
      owner as Owner,
      @EndUserText.label: 'VERIFY item'
      verify_ref as VerifyRef,
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
      _OpsCfgAll
}

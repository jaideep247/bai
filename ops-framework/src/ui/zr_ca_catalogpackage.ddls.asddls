@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Process catalogue packages'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CA_CatalogPackage
  as select from zca_ops_catpkg
  association to parent ZR_CA_OpsCfgAll as _OpsCfgAll on $projection.SingletonID = _OpsCfgAll.SingletonID
{
      @EndUserText.label: 'Catalogue package'
  key pkg_id as PkgId,
      1 as SingletonID,
      @EndUserText.label: 'Kind (S baseline, I industry, C customer)'
      pkg_kind as PkgKind,
      @EndUserText.label: 'Rank (higher extends lower)'
      pkg_rank as PkgRank,
      @EndUserText.label: 'ID prefix of objects and links'
      id_prefix as IdPrefix,
      @EndUserText.label: 'Area of the delivered monitoring'
      mon_area as MonArea,
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

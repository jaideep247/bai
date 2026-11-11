@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Process catalogue dependencies'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CA_CatalogDependency
  as select from zca_ops_catdep
  association to parent ZR_CA_OpsCfgAll as _OpsCfgAll on $projection.SingletonID = _OpsCfgAll.SingletonID
{
      @EndUserText.label: 'Business process'
  key process_id as ProcessId,
      @EndUserText.label: 'Depends on process'
  key pred_id as PredId,
      1 as SingletonID,
      @EndUserText.label: 'Dependency (H hard, S soft)'
      dep_kind as DepKind,
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

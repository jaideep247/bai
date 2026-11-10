@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Purge targets of consumers'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CA_PurgeTarget
  as select from zca_ops_purge
  association to parent ZR_CA_OpsCfgAll as _OpsCfgAll on $projection.SingletonID = _OpsCfgAll.SingletonID
{
      @EndUserText.label: 'Purge target'
  key target as Target,
      1 as SingletonID,
      @EndUserText.label: 'Class name'
      class_name as ClassName,
      @EndUserText.label: 'Area of the retention parameter'
      param_area as ParamArea,
      @EndUserText.label: 'Retention parameter (ZCA_PARAM)'
      param_name as ParamName,
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

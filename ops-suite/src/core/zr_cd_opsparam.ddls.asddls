@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Runtime parameters'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CD_OpsParam
  as select from zcd_ops_param
  association to parent ZR_CD_OpsCfgAll as _OpsCfgAll on $projection.SingletonID = _OpsCfgAll.SingletonID
{
      @EndUserText.label: 'Param name'
  key param_name as ParamName,
      1 as SingletonID,
      @EndUserText.label: 'Param value'
      param_value as ParamValue,
      @EndUserText.label: 'Description'
      description as Description,
      @EndUserText.label: 'Changed by (SM30)'
      changed_by as ChangedBy,
      @EndUserText.label: 'Changed at (SM30)'
      changed_at as ChangedAt,
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

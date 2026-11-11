@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Link registry link conditions'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CA_LinkCondition
  as select from zca_ops_lnkcnd
  association to parent ZR_CA_OpsCfgAll as _OpsCfgAll on $projection.SingletonID = _OpsCfgAll.SingletonID
{
      @EndUserText.label: 'Link'
  key link_id as LinkId,
      @EndUserText.label: 'Condition'
  key cond_no as CondNo,
      1 as SingletonID,
      @EndUserText.label: 'Kind (EQ, CONST, NOTINIT, PREFER)'
      cond_kind as CondKind,
      @EndUserText.label: 'From TABLE-FIELD'
      from_ref as FromRef,
      @EndUserText.label: 'To TABLE-FIELD'
      to_ref as ToRef,
      @EndUserText.label: 'Condition value(s)'
      cond_value as CondValue,
      @EndUserText.label: 'Transform (EQ)'
      transform as Transform,
      @EndUserText.label: 'Transform argument'
      transform_arg as TransformArg,
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

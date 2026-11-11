@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Break analysis rule conditions'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CA_BreakCondition
  as select from zca_ops_brkcnd
  association to parent ZR_CA_OpsCfgAll as _OpsCfgAll on $projection.SingletonID = _OpsCfgAll.SingletonID
{
      @EndUserText.label: 'Area (alert rules: * = every area)'
  key area as Area,
      @EndUserText.label: 'Rule ID'
  key rule_id as RuleId,
      @EndUserText.label: 'Condition'
  key cond_no as CondNo,
      1 as SingletonID,
      @EndUserText.label: 'Kind (EQ, CONST, NOTINIT, PREFER)'
      cond_kind as CondKind,
      @EndUserText.label: 'Field'
      field as Field,
      @EndUserText.label: 'Operator'
      operator as Operator,
      @EndUserText.label: 'Condition value(s)'
      cond_value as CondValue,
      @EndUserText.label: 'Link'
      link_id as LinkId,
      @EndUserText.label: 'Linked rows needed (EX, 0 = 1)'
      min_count as MinCount,
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

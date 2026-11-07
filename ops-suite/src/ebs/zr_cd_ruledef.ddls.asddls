@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Rule registry'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CD_RuleDef
  as select from zcd_ebs_rule_def
  association to parent ZR_CD_EbsCfgAll as _EbsCfgAll on $projection.SingletonID = _EbsCfgAll.SingletonID
{
      @EndUserText.label: 'Rule ID'
  key rule_id as RuleId,
      1 as SingletonID,
      @EndUserText.label: 'Rule level'
      rule_level as RuleLevel,
      @EndUserText.label: 'Class name'
      class_name as ClassName,
      @EndUserText.label: 'Default severity'
      default_severity as DefaultSeverity,
      @EndUserText.label: 'Default action'
      default_action as DefaultAction,
      @EndUserText.label: 'Description'
      description as Description,
      @EndUserText.label: 'Active'
      active as Active,
      @EndUserText.label: 'Needs posting'
      needs_posting as NeedsPosting,
      @EndUserText.label: 'Finding class'
      finding_class as FindingClass,
      @Semantics.user.lastChangedBy: true
      @EndUserText.label: 'Last changed by'
      last_changed_by as LastChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      @EndUserText.label: 'Last changed at'
      last_changed_at as LastChangedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      @EndUserText.label: 'Changed at (instance)'
      local_last_changed_at as LocalLastChangedAt,
      _EbsCfgAll
}

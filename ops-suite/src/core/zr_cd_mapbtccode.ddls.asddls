@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Bank transaction codes (typed ZBTM)'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CD_MapBtcCode
  as select from zcd_ops_mapbtm
  association to parent ZR_CD_OpsCfgAll as _OpsCfgAll on $projection.SingletonID = _OpsCfgAll.SingletonID
{
      @EndUserText.label: 'Mapping version (active: POSTAREA_VERSION_*)'
  key version as Version,
      @EndUserText.label: 'Scheme'
  key scheme as Scheme,
      @EndUserText.label: 'Code'
  key code as Code,
      @EndUserText.label: 'ISO family'
  key family as Family,
      @EndUserText.label: 'ISO sub-family (* = family row)'
  key sub_family as SubFamily,
      @EndUserText.label: 'Bank key of the statement (* = every bank)'
  key bank as Bank,
      @EndUserText.label: 'Flow'
  key flow as Flow,
      1 as SingletonID,
      @EndUserText.label: 'Category'
      category as Category,
      @EndUserText.label: 'Rule group'
      rule_group as RuleGroup,
      @EndUserText.label: 'Expected direction'
      exp_cdi as ExpCdi,
      @EndUserText.label: 'Payment method'
      pay_method as PayMethod,
      @EndUserText.label: 'Posting rule'
      posting_rule as PostingRule,
      @EndUserText.label: 'Action'
      action as ActionCode,
      @EndUserText.label: 'Disposition (POSTED / NOT_POSTED)'
      disposition as Disposition,
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

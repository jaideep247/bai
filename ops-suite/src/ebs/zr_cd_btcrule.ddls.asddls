@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Rule assignments'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CD_BtcRule
  as select from zcd_btc_rule
  association to parent ZR_CD_EbsCfgAll as _EbsCfgAll on $projection.SingletonID = _EbsCfgAll.SingletonID
{
      @EndUserText.label: 'Rule group'
  key rule_group as RuleGroup,
      @EndUserText.label: 'Rule ID'
  key rule_id as RuleId,
      1 as SingletonID,
      @EndUserText.label: 'Sequence'
      seq as Seq,
      @EndUserText.label: 'Severity'
      severity as Severity,
      @EndUserText.label: 'Action'
      action as ActionCode,
      @EndUserText.label: 'Parameter 1'
      param1 as Param1,
      @EndUserText.label: 'Parameter 2'
      param2 as Param2,
      @EndUserText.label: 'Parameter 3'
      param3 as Param3,
      @EndUserText.label: 'Tolerance'
      tolerance as Tolerance,
      @EndUserText.label: 'Window days'
      window_days as WindowDays,
      @EndUserText.label: 'Active'
      active as Active,
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
      _EbsCfgAll
}

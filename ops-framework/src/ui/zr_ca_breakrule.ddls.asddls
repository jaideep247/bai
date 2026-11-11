@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Break analysis bucket rules'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CA_BreakRule
  as select from zca_ops_brkrul
  association to parent ZR_CA_OpsCfgAll as _OpsCfgAll on $projection.SingletonID = _OpsCfgAll.SingletonID
{
      @EndUserText.label: 'Area (alert rules: * = every area)'
  key area as Area,
      @EndUserText.label: 'Rule ID'
  key rule_id as RuleId,
      1 as SingletonID,
      @EndUserText.label: 'Layer'
      layer_id as LayerId,
      @EndUserText.label: 'Display order'
      seq as Seq,
      @EndUserText.label: 'Variance bucket'
      bucket as Bucket,
      @EndUserText.label: 'Accounts (PCRE on the account ID, blank = all)'
      acct_pattern as AcctPattern,
      @EndUserText.label: 'Reason'
      reason as Reason,
      @EndUserText.label: 'Description'
      description as Description,
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

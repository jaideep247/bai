@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Runbook links per check'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CA_RunbookLink
  as select from zca_ops_runbook
  association to parent ZR_CA_OpsCfgAll as _OpsCfgAll on $projection.SingletonID = _OpsCfgAll.SingletonID
{
      @EndUserText.label: 'Area (alert rules: * = every area)'
  key area as Area,
      @EndUserText.label: 'Finding field (RULE_ID / CHECK_CODE / GROUP2)'
  key match_field as MatchField,
      @EndUserText.label: 'Value (exact)'
  key match_value as MatchValue,
      1 as SingletonID,
      @EndUserText.label: 'Runbook URL'
      runbook_url as RunbookUrl,
      @EndUserText.label: 'First action (one line)'
      first_action as FirstAction,
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

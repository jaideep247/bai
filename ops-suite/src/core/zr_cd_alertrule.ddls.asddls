@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Alert rules'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CD_AlertRule
  as select from zcd_ops_alert_rule
  association to parent ZR_CD_OpsCfgAll as _OpsCfgAll on $projection.SingletonID = _OpsCfgAll.SingletonID
{
      @EndUserText.label: 'Rule ID'
  key rule_id as RuleId,
      1 as SingletonID,
      @EndUserText.label: 'Payment engine area'
      pe_area as PaymentEngineArea,
      @EndUserText.label: 'Minimum severity'
      min_severity as MinSeverity,
      @EndUserText.label: 'Rule pattern'
      rule_pattern as RulePattern,
      @EndUserText.label: 'Check pattern'
      check_pattern as CheckPattern,
      @EndUserText.label: 'Group1 pattern'
      group1_pattern as Group1Pattern,
      @EndUserText.label: 'Group2 pattern'
      group2_pattern as Group2Pattern,
      @EndUserText.label: 'Minimum RAG'
      min_rag as MinRag,
      @EndUserText.label: 'On abort'
      on_abort as OnAbort,
      @EndUserText.label: 'Channel'
      channel as Channel,
      @EndUserText.label: 'Destination'
      destination as Destination,
      @EndUserText.label: 'Digest'
      digest as Digest,
      @EndUserText.label: 'Maximum items'
      max_items as MaxItems,
      @EndUserText.label: 'Throttle minimum'
      throttle_min as ThrottleMin,
      @EndUserText.label: 'Quiet from'
      quiet_from as QuietFrom,
      @EndUserText.label: 'Quiet to'
      quiet_to as QuietTo,
      @EndUserText.label: 'Escalate after'
      escalate_after as EscalateAfter,
      @EndUserText.label: 'Escalation destination'
      escalation_dest as EscalationDest,
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
      _OpsCfgAll
}

@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Role sequence outcomes'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CD_HckSeqOutcome
  as select from zcd_hck_seqout
  association to parent ZR_CD_HckCfgAll as _HckCfgAll on $projection.SingletonID = _HckCfgAll.SingletonID
{
      @EndUserText.label: 'Flow'
  key flow as Flow,
      @EndUserText.label: 'Method class'
  key method_class as MethodClass,
      @EndUserText.label: 'Sequence'
  key seq as Seq,
      1 as SingletonID,
      @EndUserText.label: 'Role sequence (PCRE, whole value)'
      seq_pattern as SeqPattern,
      @EndUserText.label: 'Outcome'
      outcome as Outcome,
      @EndUserText.label: 'Returns lot items expected (blank = not checked)'
      expected_dfkkrp as ExpectedDfkkrp,
      @EndUserText.label: 'Maximum age of a pending outcome (days)'
      max_age_days as MaxAgeDays,
      @EndUserText.label: 'Severity'
      severity as Severity,
      @EndUserText.label: 'Description'
      description as Description,
      @EndUserText.label: 'Register state (cheque, blank = any)'
      reg_state as RegState,
      @EndUserText.label: 'Finding code of the outcome (blank = none)'
      finding as Finding,
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
      _HckCfgAll
}

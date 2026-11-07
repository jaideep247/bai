@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Clearing / return evidence rules'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CD_HckClrRule
  as select from zcd_hck_clrrule
  association to parent ZR_CD_HckCfgAll as _HckCfgAll on $projection.SingletonID = _HckCfgAll.SingletonID
{
      @EndUserText.label: 'Flow'
  key flow as Flow,
      @EndUserText.label: 'Method class'
  key method_class as MethodClass,
      @EndUserText.label: 'Purpose'
  key purpose as Purpose,
      @EndUserText.label: 'Sequence'
  key seq as Seq,
      1 as SingletonID,
      @EndUserText.label: 'Evidence class'
      evidence_class as EvidenceClass,
      @EndUserText.label: 'Parameter 1'
      param1 as Param1,
      @EndUserText.label: 'Parameter 2'
      param2 as Param2,
      @EndUserText.label: 'Parameter 3'
      param3 as Param3,
      @EndUserText.label: 'Required (X must hold, C condition, N must not hold)'
      required as Required,
      @EndUserText.label: 'Description'
      description as Description,
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

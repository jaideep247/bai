@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Flow patterns (XBLNR)'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CD_FlowPattern
  as select from zcd_ebs_flow_pat
  association to parent ZR_CD_EbsCfgAll as _EbsCfgAll on $projection.SingletonID = _EbsCfgAll.SingletonID
{
      @EndUserText.label: 'Priority'
  key priority as Priority,
      @EndUserText.label: 'Pattern'
  key pattern as Pattern,
      1 as SingletonID,
      @EndUserText.label: 'Flow (D/C/*)'
      flow_type as FlowType,
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
      _EbsCfgAll
}

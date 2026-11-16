@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment file status mapping'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CA_PayFileStatusMap
  as select from zca_ops_pfmap
  association to parent ZR_CA_OpsCfgAll as _OpsCfgAll on $projection.SingletonID = _OpsCfgAll.SingletonID
{
      @EndUserText.label: 'Area (alert rules: * = every area)'
  key area as Area,
      @EndUserText.label: 'Source'
  key source_id as SourceId,
      @EndUserText.label: 'Native status (exact)'
  key status as Status,
      1 as SingletonID,
      @EndUserText.label: 'Milestone'
      milestone as Milestone,
      @EndUserText.label: 'Outcome'
      outcome as Outcome,
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

@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Link registry activation overrides'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CA_LinkActivation
  as select from zca_ops_lnkact
  association to parent ZR_CA_OpsCfgAll as _OpsCfgAll on $projection.SingletonID = _OpsCfgAll.SingletonID
{
      @EndUserText.label: 'Target (L layer, K link)'
  key target_kind as TargetKind,
      @EndUserText.label: 'Layer or link switched'
  key target_id as TargetId,
      1 as SingletonID,
      @EndUserText.label: 'Layer'
      layer_id as LayerId,
      @EndUserText.label: 'Active'
      active as Active,
      @EndUserText.label: 'Reason'
      reason as Reason,
      @EndUserText.label: 'Owner'
      owner as Owner,
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

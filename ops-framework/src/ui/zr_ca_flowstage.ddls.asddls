@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Account flow stages'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CA_FlowStage
  as select from zca_ops_flwstg
  association to parent ZR_CA_OpsCfgAll as _OpsCfgAll on $projection.SingletonID = _OpsCfgAll.SingletonID
{
      @EndUserText.label: 'Area (alert rules: * = every area)'
  key area as Area,
      @EndUserText.label: 'Account flow'
  key flow_id as FlowId,
      @EndUserText.label: 'Stage'
  key stage_id as StageId,
      1 as SingletonID,
      @EndUserText.label: 'Display order'
      seq as Seq,
      @EndUserText.label: 'Description'
      description as Description,
      @EndUserText.label: 'Expected: clears the open items of role'
      expect_from as ExpectFrom,
      @EndUserText.label: 'Expected: counter-posting on role'
      expect_to as ExpectTo,
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

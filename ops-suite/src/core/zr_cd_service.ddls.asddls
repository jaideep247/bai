@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Business services (health score)'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CD_Service
  as select from zcd_ops_svc
  association to parent ZR_CD_OpsCfgAll as _OpsCfgAll on $projection.SingletonID = _OpsCfgAll.SingletonID
{
      @EndUserText.label: 'Business service'
  key service as Service,
      1 as SingletonID,
      @EndUserText.label: 'Label of the stage'
      label as Label,
      @EndUserText.label: 'Sequence'
      seq as Seq,
      @EndUserText.label: 'Points per open blocking finding'
      weight_b as WeightB,
      @EndUserText.label: 'Points per open error finding'
      weight_e as WeightE,
      @EndUserText.label: 'Points per open warning finding'
      weight_w as WeightW,
      @EndUserText.label: 'Points per stale monitor'
      stale_points as StalePoints,
      @EndUserText.label: 'Good from score'
      green_min as GreenMin,
      @EndUserText.label: 'Watch from score'
      amber_min as AmberMin,
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

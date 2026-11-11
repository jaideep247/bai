@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Break analysis buckets'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CA_BreakBucket
  as select from zca_ops_brkbkt
  association to parent ZR_CA_OpsCfgAll as _OpsCfgAll on $projection.SingletonID = _OpsCfgAll.SingletonID
{
      @EndUserText.label: 'Variance bucket'
  key bucket as Bucket,
      1 as SingletonID,
      @EndUserText.label: 'Description'
      description as Description,
      @EndUserText.label: 'Explained (counts as explained)'
      explained as Explained,
      @EndUserText.label: 'Layer'
      layer_id as LayerId,
      @EndUserText.label: 'Display order'
      seq as Seq,
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

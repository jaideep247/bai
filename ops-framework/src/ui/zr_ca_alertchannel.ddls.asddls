@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Alert channels'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CA_AlertChannel
  as select from zca_ops_alchn
  association to parent ZR_CA_OpsCfgAll as _OpsCfgAll on $projection.SingletonID = _OpsCfgAll.SingletonID
{
      @EndUserText.label: 'Channel'
  key channel as Channel,
      1 as SingletonID,
      @EndUserText.label: 'Class name'
      class_name as ClassName,
      @EndUserText.label: 'Destination'
      destination as Destination,
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

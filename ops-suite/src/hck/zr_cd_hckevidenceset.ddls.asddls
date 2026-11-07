@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Evidence settings'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CD_HckEvidenceSet
  as select from zcd_hck_evset
  association to parent ZR_CD_HckCfgAll as _HckCfgAll on $projection.SingletonID = _HckCfgAll.SingletonID
{
      @EndUserText.label: 'Set ID'
  key set_id as SetId,
      @EndUserText.label: 'Name'
  key name as Name,
      1 as SingletonID,
      @EndUserText.label: 'Value'
      value as Value,
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

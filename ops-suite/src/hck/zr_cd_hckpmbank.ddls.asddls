@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Factory calendar per house bank'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CD_HckPmBank
  as select from zcd_hck_pmbank
  association to parent ZR_CD_HckCfgAll as _HckCfgAll on $projection.SingletonID = _HckCfgAll.SingletonID
{
      @EndUserText.label: 'Flow'
  key flow as Flow,
      @EndUserText.label: 'Method class'
  key method_class as MethodClass,
      @EndUserText.label: 'House bank'
  key hbkid as Hbkid,
      1 as SingletonID,
      @EndUserText.label: 'Calendar'
      calendar as Calendar,
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

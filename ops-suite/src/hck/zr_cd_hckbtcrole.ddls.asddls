@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Bank transaction code roles'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CD_HckBtcRole
  as select from zcd_hck_btcrole
  association to parent ZR_CD_HckCfgAll as _HckCfgAll on $projection.SingletonID = _HckCfgAll.SingletonID
{
      @EndUserText.label: 'Flow'
  key flow as Flow,
      @EndUserText.label: 'Method class'
  key method_class as MethodClass,
      @EndUserText.label: 'Scheme'
  key scheme as Scheme,
      @EndUserText.label: 'BTC code'
  key btc_code as BtcCode,
      1 as SingletonID,
      @EndUserText.label: 'Role'
      role as Role,
      @EndUserText.label: 'Compare amount (X returns lot, R payment, C correction)'
      compare_amount as CompareAmount,
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

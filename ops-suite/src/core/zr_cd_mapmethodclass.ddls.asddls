@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment method classes (typed ZPMC)'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CD_MapMethodClass
  as select from zcd_ops_mappmc
  association to parent ZR_CD_OpsCfgAll as _OpsCfgAll on $projection.SingletonID = _OpsCfgAll.SingletonID
{
      @EndUserText.label: 'Mapping version (active: POSTAREA_VERSION_*)'
  key version as Version,
      @EndUserText.label: 'Flow'
  key flow as Flow,
      @EndUserText.label: 'Payment method'
  key pay_method as PayMethod,
      @EndUserText.label: 'House bank (* = every house bank)'
  key house_bank as HouseBank,
      1 as SingletonID,
      @EndUserText.label: 'Method class'
      method_class as MethodClass,
      @EndUserText.label: 'Ageing basis'
      age_basis as AgeBasis,
      @EndUserText.label: 'Calendar'
      calendar as Calendar,
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

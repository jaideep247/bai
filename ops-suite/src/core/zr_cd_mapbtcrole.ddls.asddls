@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Bank code roles (typed ZBTR)'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CD_MapBtcRole
  as select from zcd_ops_mapbtr
  association to parent ZR_CD_OpsCfgAll as _OpsCfgAll on $projection.SingletonID = _OpsCfgAll.SingletonID
{
      @EndUserText.label: 'Mapping version (active: POSTAREA_VERSION_*)'
  key version as Version,
      @EndUserText.label: 'Usage (LIFECYCLE / RECON)'
  key usage as Usage,
      @EndUserText.label: 'Scope (lifecycle: flow + method class; recon: set ID)'
  key scope as Scope,
      @EndUserText.label: 'Scheme'
  key scheme as Scheme,
      @EndUserText.label: 'Code'
  key code as Code,
      @EndUserText.label: 'ISO family'
  key family as Family,
      @EndUserText.label: 'ISO sub-family (* = family row)'
  key sub_family as SubFamily,
      1 as SingletonID,
      @EndUserText.label: 'Role'
      role as Role,
      @EndUserText.label: 'Compare amount (X returns lot, R payment, C correction)'
      compare_amount as CompareAmount,
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

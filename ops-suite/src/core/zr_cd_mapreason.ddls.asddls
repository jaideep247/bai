@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Return / NOC reasons (typed ZRSN)'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CD_MapReason
  as select from zcd_ops_maprsn
  association to parent ZR_CD_OpsCfgAll as _OpsCfgAll on $projection.SingletonID = _OpsCfgAll.SingletonID
{
      @EndUserText.label: 'Mapping version (active: POSTAREA_VERSION_*)'
  key version as Version,
      @EndUserText.label: 'Reason'
  key reason as Reason,
      1 as SingletonID,
      @EndUserText.label: 'Payment engine reason'
      fica_reason as FicaReason,
      @EndUserText.label: 'NOC reason'
      is_noc as IsNoc,
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

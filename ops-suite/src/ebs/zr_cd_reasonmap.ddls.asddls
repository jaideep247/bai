@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Return / NOC reasons'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CD_ReasonMap
  as select from zcd_ebs_rsn_map
  association to parent ZR_CD_EbsCfgAll as _EbsCfgAll on $projection.SingletonID = _EbsCfgAll.SingletonID
{
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
      _EbsCfgAll
}

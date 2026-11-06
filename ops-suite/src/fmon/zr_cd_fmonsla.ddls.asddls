@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Stage SLAs'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CD_FmonSla
  as select from zcd_fmon_sla
  association to parent ZR_CD_FmonCfgAll as _FmonCfgAll on $projection.SingletonID = _FmonCfgAll.SingletonID
{
      @EndUserText.label: 'Interface ID'
  key iface_id as IfaceId,
      @EndUserText.label: 'Stage'
  key stage as Stage,
      1 as SingletonID,
      @EndUserText.label: 'Maximum minutes'
      max_minutes as MaxMinutes,
      @EndUserText.label: 'Basis'
      basis as Basis,
      @EndUserText.label: 'Severity'
      severity as Severity,
      @Semantics.user.lastChangedBy: true
      @EndUserText.label: 'Last changed by'
      last_changed_by as LastChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      @EndUserText.label: 'Last changed at'
      last_changed_at as LastChangedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      @EndUserText.label: 'Changed at (instance)'
      local_last_changed_at as LocalLastChangedAt,
      _FmonCfgAll
}

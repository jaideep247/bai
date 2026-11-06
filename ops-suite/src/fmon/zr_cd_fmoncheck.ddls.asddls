@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Checks'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CD_FmonCheck
  as select from zcd_fmon_chk
  association to parent ZR_CD_FmonCfgAll as _FmonCfgAll on $projection.SingletonID = _FmonCfgAll.SingletonID
{
      @EndUserText.label: 'Check ID'
  key check_id as CheckId,
      1 as SingletonID,
      @EndUserText.label: 'Class name'
      class_name as ClassName,
      @EndUserText.label: 'Severity'
      severity as Severity,
      @EndUserText.label: 'Active'
      active as Active,
      @EndUserText.label: 'Parameters'
      params as Params,
      @EndUserText.label: 'Description'
      description as Description,
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

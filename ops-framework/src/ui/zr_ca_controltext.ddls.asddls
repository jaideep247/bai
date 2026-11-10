@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Control guidance per language'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CA_ControlText
  as select from zca_ops_ctlt
  association to parent ZR_CA_OpsCfgAll as _OpsCfgAll on $projection.SingletonID = _OpsCfgAll.SingletonID
{
      @EndUserText.label: 'Language'
  key langu as Langu,
      @EndUserText.label: 'Area (alert rules: * = every area)'
  key area as Area,
      @EndUserText.label: 'Control ID'
  key control_id as ControlId,
      1 as SingletonID,
      @EndUserText.label: 'Guidance for the reviewer'
      guidance as Guidance,
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

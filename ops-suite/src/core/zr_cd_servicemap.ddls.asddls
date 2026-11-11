@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'What a business service covers'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CD_ServiceMap
  as select from zcd_ops_svcmap
  association to parent ZR_CD_OpsCfgAll as _OpsCfgAll on $projection.SingletonID = _OpsCfgAll.SingletonID
{
      @EndUserText.label: 'Business service'
  key service as Service,
      @EndUserText.label: 'Area (* = every area)'
  key area as Area,
      @EndUserText.label: 'Covers (AREA / CONTROL / RULE_ID / CHECK_CODE / GROUP2)'
  key match_field as MatchField,
      @EndUserText.label: 'Payment status (PAYRUN) / worklist outcome or stage (REQUEST)'
  key match_value as MatchValue,
      1 as SingletonID,
      @EndUserText.label: 'Weight (multiplier)'
      weight as Weight,
      @EndUserText.label: 'Active'
      active as Active,
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

@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Alert correlation rules'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CA_CorrelationRule
  as select from zca_ops_corr
  association to parent ZR_CA_OpsCfgAll as _OpsCfgAll on $projection.SingletonID = _OpsCfgAll.SingletonID
{
      @EndUserText.label: 'Area (alert rules: * = every area)'
  key area as Area,
      @EndUserText.label: 'Correlation rule'
  key corr_rule as CorrRule,
      1 as SingletonID,
      @EndUserText.label: 'Description'
      description as Description,
      @EndUserText.label: 'Check pattern'
      check_pattern as CheckPattern,
      @EndUserText.label: 'Key fields (finding fields, comma list)'
      key_fields as KeyFields,
      @EndUserText.label: 'Key pattern (PCRE, group 1)'
      key_pattern as KeyPattern,
      @EndUserText.label: 'Window (minutes from the parent)'
      window_min as WindowMin,
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

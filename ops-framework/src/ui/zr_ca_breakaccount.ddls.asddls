@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Break analysis clearing accounts'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CA_BreakAccount
  as select from zca_ops_brkacc
  association to parent ZR_CA_OpsCfgAll as _OpsCfgAll on $projection.SingletonID = _OpsCfgAll.SingletonID
{
      @EndUserText.label: 'Area (alert rules: * = every area)'
  key area as Area,
      @EndUserText.label: 'Clearing account ID'
  key acct_id as AcctId,
      1 as SingletonID,
      @EndUserText.label: 'Company code'
      bukrs as Bukrs,
      @EndUserText.label: 'G/L clearing account'
      hkont as Hkont,
      @EndUserText.label: 'Ledger (blank = BRK_LEDGER)'
      ledger as Ledger,
      @EndUserText.label: 'Business process'
      process_id as ProcessId,
      @EndUserText.label: 'Days before the key date (0 = parameter)'
      lookback_days as LookbackDays,
      @EndUserText.label: 'Days after the key date (0 = parameter)'
      forward_days as ForwardDays,
      @EndUserText.label: 'Groups at most (0 = parameter)'
      max_groups as MaxGroups,
      @EndUserText.label: 'Description'
      description as Description,
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

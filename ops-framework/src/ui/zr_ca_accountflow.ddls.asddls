@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Account flows'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CA_AccountFlow
  as select from zca_ops_flow
  association to parent ZR_CA_OpsCfgAll as _OpsCfgAll on $projection.SingletonID = _OpsCfgAll.SingletonID
{
      @EndUserText.label: 'Area (alert rules: * = every area)'
  key area as Area,
      @EndUserText.label: 'Account flow'
  key flow_id as FlowId,
      1 as SingletonID,
      @EndUserText.label: 'Description'
      description as Description,
      @EndUserText.label: 'Direction (D disbursement, C collection)'
      direction as Direction,
      @EndUserText.label: 'Ledger (blank = FLOW_LEDGER)'
      jrnl_ledger as JrnlLedger,
      @EndUserText.label: 'Business process'
      process_id as ProcessId,
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

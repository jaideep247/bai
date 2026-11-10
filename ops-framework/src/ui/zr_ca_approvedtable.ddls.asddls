@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Tables approved for aggregate checks'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CA_ApprovedTable
  as select from zca_ops_tabwl
  association to parent ZR_CA_OpsCfgAll as _OpsCfgAll on $projection.SingletonID = _OpsCfgAll.SingletonID
{
      @EndUserText.label: 'Area (alert rules: * = every area)'
  key area as Area,
      @EndUserText.label: 'Table'
  key table_name as TableName,
      1 as SingletonID,
      @EndUserText.label: 'Active'
      active as Active,
      @EndUserText.label: 'Approved by (reviewer)'
      approved_by as ApprovedBy,
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
      _OpsCfgAll
}

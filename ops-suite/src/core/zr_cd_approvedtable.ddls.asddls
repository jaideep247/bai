@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Approved tables per reader'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CD_ApprovedTable
  as select from zcd_ops_tabwl
  association to parent ZR_CD_OpsCfgAll as _OpsCfgAll on $projection.SingletonID = _OpsCfgAll.SingletonID
{
      @EndUserText.label: 'Payment engine area'
  key pe_area as PaymentEngineArea,
      @EndUserText.label: 'Purpose (FMON: SOURCE; HCK: READ / DRIFT)'
  key purpose as Purpose,
      @EndUserText.label: 'Table name'
  key table_name as TableName,
      @EndUserText.label: 'Field (blank = whole table)'
  key field_name as FieldName,
      1 as SingletonID,
      @EndUserText.label: 'Active'
      active as Active,
      @EndUserText.label: 'Approved by'
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

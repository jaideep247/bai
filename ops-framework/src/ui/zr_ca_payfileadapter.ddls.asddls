@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment file adapters'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CA_PayFileAdapter
  as select from zca_ops_pfadp
  association to parent ZR_CA_OpsCfgAll as _OpsCfgAll on $projection.SingletonID = _OpsCfgAll.SingletonID
{
      @EndUserText.label: 'Area (alert rules: * = every area)'
  key area as Area,
      @EndUserText.label: 'Payment file type'
  key file_type as FileType,
      @EndUserText.label: 'Role (RECEIVABLE, PAYABLE, OUTSIDE, CLEARING, ...)'
  key role as Role,
      1 as SingletonID,
      @EndUserText.label: 'Source'
      source_id as SourceId,
      @EndUserText.label: 'Class name'
      class_name as ClassName,
      @EndUserText.label: 'Adapter setting'
      setting as Setting,
      @EndUserText.label: 'Source type (SAP, MW, BANK)'
      source_type as SourceType,
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

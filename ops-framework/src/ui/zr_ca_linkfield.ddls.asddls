@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Link registry object fields'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CA_LinkField
  as select from zca_ops_lnkfld
  association to parent ZR_CA_OpsCfgAll as _OpsCfgAll on $projection.SingletonID = _OpsCfgAll.SingletonID
{
      @EndUserText.label: 'Business object'
  key object_id as ObjectId,
      @EndUserText.label: 'Field'
  key field_name as FieldName,
      1 as SingletonID,
      @EndUserText.label: 'Layer'
      layer_id as LayerId,
      @EndUserText.label: 'Table or CDS view'
      source_name as SourceName,
      @EndUserText.label: 'Data element'
      data_element as DataElement,
      @EndUserText.label: 'Sensitivity (M masked, H hidden)'
      sensitivity as Sensitivity,
      @EndUserText.label: 'Evidence (C confirmed, V VERIFY)'
      evidence as Evidence,
      @EndUserText.label: 'VERIFY item'
      verify_ref as VerifyRef,
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

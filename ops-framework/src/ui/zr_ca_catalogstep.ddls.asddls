@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Process catalogue steps'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CA_CatalogStep
  as select from zca_ops_catstp
  association to parent ZR_CA_OpsCfgAll as _OpsCfgAll on $projection.SingletonID = _OpsCfgAll.SingletonID
{
      @EndUserText.label: 'Business process'
  key process_id as ProcessId,
      @EndUserText.label: 'Step'
  key step_no as StepNo,
      1 as SingletonID,
      @EndUserText.label: 'Kind (T, P, M, J, E)'
      step_kind as StepKind,
      @EndUserText.label: 'SAP object'
      obj_name as ObjName,
      @EndUserText.label: 'Description'
      description as Description,
      @EndUserText.label: 'Evidence (C confirmed, V VERIFY)'
      evidence as Evidence,
      @EndUserText.label: 'VERIFY item'
      verify_ref as VerifyRef,
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

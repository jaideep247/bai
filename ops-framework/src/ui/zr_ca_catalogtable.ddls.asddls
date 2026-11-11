@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Process catalogue tables'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CA_CatalogTable
  as select from zca_ops_cattab
  association to parent ZR_CA_OpsCfgAll as _OpsCfgAll on $projection.SingletonID = _OpsCfgAll.SingletonID
{
      @EndUserText.label: 'Business process'
  key process_id as ProcessId,
      @EndUserText.label: 'Table (approved for the area)'
  key tabname as Tabname,
      1 as SingletonID,
      @EndUserText.label: 'Role (H, I, L, S, C)'
      tab_role as TabRole,
      @EndUserText.label: 'Link registry object'
      link_object as LinkObject,
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

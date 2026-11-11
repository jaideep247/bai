@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Process catalogue processes'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CA_CatalogProcess
  as select from zca_ops_catprc
  association to parent ZR_CA_OpsCfgAll as _OpsCfgAll on $projection.SingletonID = _OpsCfgAll.SingletonID
{
      @EndUserText.label: 'Business process'
  key process_id as ProcessId,
      1 as SingletonID,
      @EndUserText.label: 'Catalogue package'
      pkg_id as PkgId,
      @EndUserText.label: 'Description'
      description as Description,
      @EndUserText.label: 'SAP component'
      component as Component,
      @EndUserText.label: 'Dashboard card'
      dash_card as DashCard,
      @EndUserText.label: 'Business owner role'
      owner_role as OwnerRole,
      @EndUserText.label: 'Typical schedule'
      schedule as Schedule,
      @EndUserText.label: 'Active by default (no activation row)'
      dflt_active as DfltActive,
      @EndUserText.label: 'Evidence (C confirmed, V VERIFY)'
      evidence as Evidence,
      @EndUserText.label: 'VERIFY item'
      verify_ref as VerifyRef,
      @EndUserText.label: 'Display order'
      seq as Seq,
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

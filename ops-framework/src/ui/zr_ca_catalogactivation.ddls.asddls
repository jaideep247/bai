@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Process catalogue activation'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CA_CatalogActivation
  as select from zca_ops_catact
  association to parent ZR_CA_OpsCfgAll as _OpsCfgAll on $projection.SingletonID = _OpsCfgAll.SingletonID
{
      @EndUserText.label: 'Business process'
  key process_id as ProcessId,
      @EndUserText.label: 'Effective from'
  key valid_from as ValidFrom,
      1 as SingletonID,
      @EndUserText.label: 'Active'
      active as Active,
      @EndUserText.label: 'Catalogue package'
      pkg_id as PkgId,
      @EndUserText.label: 'Reason'
      reason as Reason,
      @EndUserText.label: 'Approved by (reviewer)'
      approved_by as ApprovedBy,
      @EndUserText.label: 'Approved on'
      approved_on as ApprovedOn,
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

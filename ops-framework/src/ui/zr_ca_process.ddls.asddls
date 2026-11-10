@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Business processes'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CA_Process
  as select from zca_ops_proc
  association to parent ZR_CA_OpsCfgAll as _OpsCfgAll on $projection.SingletonID = _OpsCfgAll.SingletonID
{
      @EndUserText.label: 'Area (alert rules: * = every area)'
  key area as Area,
      @EndUserText.label: 'Business process'
  key process_id as ProcessId,
      1 as SingletonID,
      @EndUserText.label: 'Description'
      description as Description,
      @EndUserText.label: 'Owner'
      owner as Owner,
      @EndUserText.label: 'Backup'
      backup as Backup,
      @EndUserText.label: 'Runbook URL'
      runbook_url as RunbookUrl,
      @EndUserText.label: 'Role (PFCG) granting ZCA_OPS for the area'
      auth_role as AuthRole,
      @EndUserText.label: 'Writes own tables (purge target required)'
      own_data as OwnData,
      @EndUserText.label: 'Purge target of own tables'
      purge_target as PurgeTarget,
      @EndUserText.label: 'Active'
      active as Active,
      @EndUserText.label: 'Seq'
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

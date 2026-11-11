@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Registered checks'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CA_RegisteredCheck
  as select from zca_ops_check
  association to parent ZR_CA_OpsCfgAll as _OpsCfgAll on $projection.SingletonID = _OpsCfgAll.SingletonID
{
      @EndUserText.label: 'Area (alert rules: * = every area)'
  key area as Area,
      @EndUserText.label: 'Check ID'
  key check_id as CheckId,
      1 as SingletonID,
      @EndUserText.label: 'Business process'
      process_id as ProcessId,
      @EndUserText.label: 'Description'
      description as Description,
      @EndUserText.label: 'Class name'
      class_name as ClassName,
      @EndUserText.label: 'Schedule group (run variant)'
      sched_group as SchedGroup,
      @EndUserText.label: 'Reports per company code'
      bukrs_aware as BukrsAware,
      @EndUserText.label: 'Active'
      active as Active,
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

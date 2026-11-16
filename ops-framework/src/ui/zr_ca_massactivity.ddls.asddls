@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Mass activities and their output'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CA_MassActivity
  as select from zca_ops_maact
  association to parent ZR_CA_OpsCfgAll as _OpsCfgAll on $projection.SingletonID = _OpsCfgAll.SingletonID
{
      @EndUserText.label: 'Area (alert rules: * = every area)'
  key area as Area,
      @EndUserText.label: 'Mass activity'
  key act_id as ActId,
      1 as SingletonID,
      @EndUserText.label: 'Description'
      description as Description,
      @EndUserText.label: 'Mass activity type'
      aktyp as Aktyp,
      @EndUserText.label: 'Program of the parent job (exact, blank = any)'
      parent_program as ParentProgram,
      @EndUserText.label: 'Parent job names (PCRE, complete name)'
      job_pattern as JobPattern,
      @EndUserText.label: 'Output rule (PAYDOC, DUNNING, NONE)'
      output_kind as OutputKind,
      @EndUserText.label: 'Minimum output (0 = none)'
      min_output as MinOutput,
      @EndUserText.label: 'Interval run limit (minutes, 0 = MA_RUN_LIMIT_MIN)'
      run_limit_min as RunLimitMin,
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

@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Job cycle steps'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CD_JobStep
  as select from zcd_job_step
  association to parent ZR_CD_HckCfgAll as _HckCfgAll on $projection.SingletonID = _HckCfgAll.SingletonID
{
      @EndUserText.label: 'Cycle ID'
  key cycle_id as CycleId,
      @EndUserText.label: 'Step number'
  key step_no as StepNo,
      1 as SingletonID,
      @EndUserText.label: 'Description'
      description as Description,
      @EndUserText.label: 'Jobname'
      jobname as Jobname,
      @EndUserText.label: 'Program'
      program as Program,
      @EndUserText.label: 'Variant'
      variant as Variant,
      @EndUserText.label: 'Predecessor step'
      pred_step as PredStep,
      @EndUserText.label: 'Day offset'
      day_offset as DayOffset,
      @EndUserText.label: 'Window from'
      window_from as WindowFrom,
      @EndUserText.label: 'Window to'
      window_to as WindowTo,
      @EndUserText.label: 'Maximum runtime minimum'
      max_runtime_min as MaxRuntimeMin,
      @EndUserText.label: 'Skippable'
      skippable as Skippable,
      @EndUserText.label: 'Critical'
      critical as Critical,
      @EndUserText.label: 'Changed by (SM30)'
      changed_by as ChangedBy,
      @EndUserText.label: 'Changed at (SM30)'
      changed_at as ChangedAt,
      @Semantics.user.lastChangedBy: true
      @EndUserText.label: 'Last changed by'
      last_changed_by as LastChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      @EndUserText.label: 'Last changed at'
      last_changed_at as LastChangedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      @EndUserText.label: 'Changed at (instance)'
      local_last_changed_at as LocalLastChangedAt,
      _HckCfgAll
}

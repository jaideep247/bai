@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Scheduler jobs and SAP job names'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CA_SchedulerJob
  as select from zca_ops_jobsch
  association to parent ZR_CA_OpsCfgAll as _OpsCfgAll on $projection.SingletonID = _OpsCfgAll.SingletonID
{
      @EndUserText.label: 'Scheduler folder'
  key sched_folder as SchedFolder,
      @EndUserText.label: 'Scheduler job'
  key sched_job as SchedJob,
      1 as SingletonID,
      @EndUserText.label: 'SAP job names (PCRE, complete name)'
      sap_pattern as SapPattern,
      @EndUserText.label: 'Criticality (H / M / L)'
      criticality as Criticality,
      @EndUserText.label: 'Description'
      description as Description,
      @EndUserText.label: 'Active'
      active as Active,
      @EndUserText.label: 'Display order'
      seq as Seq,
      @EndUserText.label: 'Run days (Mon-Sun, X = runs; blank = none)'
      plan_days as PlanDays,
      @EndUserText.label: 'Planned start (system time)'
      plan_time as PlanTime,
      @EndUserText.label: 'Late after (minutes, 0 = XRUN_LATE_MIN)'
      late_min as LateMin,
      @EndUserText.label: 'Factory calendar (SCAL)'
      calendar_id as CalendarId,
      @EndUserText.label: 'Predecessor folder'
      pred_folder as PredFolder,
      @EndUserText.label: 'Predecessor job'
      pred_job as PredJob,
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

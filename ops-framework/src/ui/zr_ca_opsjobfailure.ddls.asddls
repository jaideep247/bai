// Artifact: zr_ca_opsjobfailure.ddls.asddls
// Purpose: SAP job failures board (service ZUI_CA_OPS_JOBS): one row per job kept by the SAP job monitor
//          (ZCA_OPS_JOB) - failures with their finding (role F: cancelled, failed child under a root that did not
//          abort, job log errors, long-running, not started) and their context (role A ancestors, role C children
//          of a failing job's parent). The evidence chain: status at detection and the live TBTCO status while the
//          job tables still hold the job (blank after the reorganisation), planned / created / start / end,
//          scheduling user, server, start event, parent with resolver and evidence quality (C confirmed, P
//          probable), root, the external scheduler job of the root and its criticality, job log error lines and
//          linked application logs (counted), business objects of the enrichers (associations), the open exception
//          of the finding (exceptions app ZUI_CA_OPS_EXC). Counters for the "Job failures today" cards (server date).
//          Nothing stored, read-only (no behaviour definition).
// Modification log: 2026-11-11 | Initial version (SAP job monitor).
// VERIFY-ADT V66: a left outer join to the cross-client table TBTCO (client handling, AUTHCKMAN not needed: the
//                 key is unique), a self association (parent / children), $session.system_date in a CASE.
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'SAP job failures'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define root view entity ZR_CA_OpsJobFailure
  as select from    zca_ops_job     as Job
    left outer join tbtco           as Live on  Live.jobname  = Job.jobname
                                            and Live.jobcount = Job.jobcount
    left outer join ZI_CA_OpsJobExc as Exc  on  Exc.Area        = Job.area
                                            and Exc.ObjectKey   = Job.object_key
                                            and Exc.CheckCode   = Job.check_code
                                            and Exc.CompanyCode = Job.bukrs
  association [0..*] to ZR_CA_OpsJobFailure as _Children        on  _Children.ParentJobName  = $projection.JobName
                                                                and _Children.ParentJobCount = $projection.JobCount
  association [0..1] to ZR_CA_OpsJobFailure as _Parent          on  _Parent.JobName  = $projection.ParentJobName
                                                                and _Parent.JobCount = $projection.ParentJobCount
  association [0..*] to ZC_CA_OpsJobStep    as _Steps           on  _Steps.JobName  = $projection.JobName
                                                                and _Steps.JobCount = $projection.JobCount
  association [0..*] to ZC_CA_OpsJobMsg     as _Messages        on  _Messages.JobName  = $projection.JobName
                                                                and _Messages.JobCount = $projection.JobCount
  association [0..*] to ZC_CA_OpsJobAlog    as _AppLogs         on  _AppLogs.JobName  = $projection.JobName
                                                                and _AppLogs.JobCount = $projection.JobCount
  association [0..*] to ZC_CA_OpsJobBo      as _BusinessObjects on  _BusinessObjects.JobName  = $projection.JobName
                                                                and _BusinessObjects.JobCount = $projection.JobCount
{
  key Job.jobname                                           as JobName,
  key Job.jobcount                                          as JobCount,
      Job.area                                              as Area,
      Job.bukrs                                             as CompanyCode,
      Job.job_role                                          as JobRole,
      cast( case Job.job_role when 'F' then 'X' else ' ' end as abap_boolean ) as IsFailure,
      Job.check_code                                        as CheckCode,
      Job.severity                                          as Severity,
      cast( case Job.severity when 'B' then 1
                              when 'E' then 1
                              when 'W' then 2
                              when 'I' then 0
                              else 3 end as abap.int1 )     as SeverityCriticality,
      Job.object_key                                        as ObjectKey,
      Job.status                                            as StatusAtDetection,
      // live status while TBTCO still holds the job; blank = deleted by the job reorganisation
      Live.status                                           as LiveStatus,
      Job.planned_date                                      as PlannedDate,
      Job.planned_time                                      as PlannedTime,
      Job.created_date                                      as CreatedDate,
      Job.created_time                                      as CreatedTime,
      Job.start_date                                        as StartDate,
      Job.start_time                                        as StartTime,
      Job.end_date                                          as EndDate,
      Job.end_time                                          as EndTime,
      Job.sched_user                                        as ScheduledBy,
      Job.server                                            as Server,
      Job.event_id                                          as EventId,
      Job.event_parm                                        as EventParameter,
      Job.parent_jobname                                    as ParentJobName,
      Job.parent_jobcount                                   as ParentJobCount,
      Job.link_resolver                                     as LinkResolver,
      Job.link_quality                                      as LinkQuality,
      Job.root_jobname                                      as RootJobName,
      Job.root_jobcount                                     as RootJobCount,
      Job.root_status                                       as RootStatus,
      Job.depth                                             as Depth,
      Job.sched_folder                                      as SchedulerFolder,
      Job.sched_job                                         as SchedulerJob,
      Job.criticality                                       as SchedulerCriticality,
      Job.log_errors                                        as LogErrors,
      Job.failed_children                                   as FailedChildren,
      Job.claimed_by                                        as ClaimedBy,
      Job.detected_at                                       as DetectedAt,
      Job.detected_on                                       as DetectedOn,
      Job.run_id                                            as RunId,
      Exc.Disposition                                       as ExceptionStatus,
      Exc.Owner                                             as ExceptionOwner,
      Exc.DueDate                                           as ExceptionDueDate,
      cast( case when Exc.Disposition is null then ' ' else 'X' end as abap_boolean ) as HasOpenException,
      cast( case when Job.detected_on = $session.system_date then 'X' else ' ' end as abap_boolean ) as IsToday,
      // Counters of the overview cards "Job failures today" (summed after the DCL)
      cast( case when Job.job_role = 'F' and Job.detected_on = $session.system_date
                 then 1 else 0 end as abap.int4 )           as FailuresToday,
      cast( case when Job.check_code = 'JOB_ABORTED' and Job.detected_on = $session.system_date
                 then 1 else 0 end as abap.int4 )           as AbortedToday,
      cast( case when Job.check_code = 'JOB_CHILD_FAILED' and Job.detected_on = $session.system_date
                 then 1 else 0 end as abap.int4 )           as ChildFailedToday,
      cast( case when Job.check_code = 'JOB_NOT_STARTED' and Job.detected_on = $session.system_date
                 then 1 else 0 end as abap.int4 )           as NotStartedToday,
      cast( case when Job.check_code = 'JOB_LONG_RUNNING' and Job.detected_on = $session.system_date
                 then 1 else 0 end as abap.int4 )           as LongRunningToday,
      cast( case when Job.check_code = 'JOB_LOG_ERROR' and Job.detected_on = $session.system_date
                 then 1 else 0 end as abap.int4 )           as LogErrorToday,
      _Children,
      _Parent,
      _Steps,
      _Messages,
      _AppLogs,
      _BusinessObjects
}

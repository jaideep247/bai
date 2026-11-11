// Artifact: zc_ca_opsjobfailure.ddls.asddls
// Purpose: Consumption view of the SAP job failures board (service ZUI_CA_OPS_JOBS, list report and object page
//          "SAP job failures"): the kept jobs with their chain (parent, children, root, external scheduler job),
//          steps, job log errors, application logs, business objects and the open exception. Also exposed by a
//          consumer's overview page (KPI card "Job failures today", list card; annotations in the metadata
//          extension). Read access: DCL ZC_CA_OPSJOBFAILURE (ZCA_OPS 03 for the area and, for a job with a company
//          code, its BUKRS). Read-only.
// Modification log: 2026-11-11 | Initial version (SAP job monitor).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'SAP job failures'
@Metadata.allowExtensions: true
@Search.searchable: true
define root view entity ZC_CA_OpsJobFailure
  provider contract transactional_query
  as projection on ZR_CA_OpsJobFailure
{
      @Search.defaultSearchElement: true
  key JobName,
  key JobCount,
      Area,
      CompanyCode,
      JobRole,
      IsFailure,
      @Search.defaultSearchElement: true
      CheckCode,
      Severity,
      SeverityCriticality,
      ObjectKey,
      StatusAtDetection,
      LiveStatus,
      PlannedDate,
      PlannedTime,
      CreatedDate,
      CreatedTime,
      StartDate,
      StartTime,
      EndDate,
      EndTime,
      ScheduledBy,
      Server,
      EventId,
      EventParameter,
      ParentJobName,
      ParentJobCount,
      LinkResolver,
      LinkQuality,
      @Search.defaultSearchElement: true
      RootJobName,
      RootJobCount,
      RootStatus,
      Depth,
      @Search.defaultSearchElement: true
      SchedulerFolder,
      @Search.defaultSearchElement: true
      SchedulerJob,
      SchedulerCriticality,
      LogErrors,
      FailedChildren,
      ClaimedBy,
      DetectedAt,
      DetectedOn,
      RunId,
      ExceptionStatus,
      ExceptionOwner,
      ExceptionDueDate,
      HasOpenException,
      IsToday,
      @Aggregation.default: #SUM
      FailuresToday,
      @Aggregation.default: #SUM
      AbortedToday,
      @Aggregation.default: #SUM
      ChildFailedToday,
      @Aggregation.default: #SUM
      NotStartedToday,
      @Aggregation.default: #SUM
      LongRunningToday,
      @Aggregation.default: #SUM
      LogErrorToday,
      _Children : redirected to ZC_CA_OpsJobFailure,
      _Parent   : redirected to ZC_CA_OpsJobFailure,
      _Steps,
      _Messages,
      _AppLogs,
      _BusinessObjects
}

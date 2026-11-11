// Artifact: zc_ca_opscheckstatus.ddls.asddls
// Purpose: Consumption view of the area dashboard (service ZUI_CA_OPS_DASH, list report "Checks by area"):
//          per area, registered check and company-code slice - process, last run, status, open exceptions,
//          freshness. Also exposed by a consumer's overview page (KPI card "Business processes", list card
//          "Process checks - attention"; annotations in the metadata extension). Read access: DCL ZC_CA_OPSCHECKSTATUS (ZCA_OPS 03 for the area and, for a company-code
//          slice, its BUKRS). Read-only.
// Modification log: 2026-11-10 | Initial version (process onboarding: area dashboard and freshness).
//                   2026-11-10 | Overview card counters (CheckCount, StaleCount, IsAttention), summed by default.
//                   2026-11-11 | Planned downtime mark of the area (operations response features).
//                   2026-11-11 | Process catalogue: catalogue process and dashboard card of the check's process.
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Area dashboard: status per check'
@Metadata.allowExtensions: true
@Search.searchable: true
define root view entity ZC_CA_OpsCheckStatus
  provider contract transactional_query
  as projection on ZR_CA_OpsCheckStatus
{
      @Search.defaultSearchElement: true
  key Area,
      @Search.defaultSearchElement: true
  key CheckId,
  key CompanyCode,
      @Search.defaultSearchElement: true
      ProcessId,
      ProcessName,
      CatalogueProcess,
      DashboardCard,
      CheckName,
      ScheduleGroup,
      ClassName,
      IsCompanyCodeAware,
      LastRunId,
      LastRunAt,
      LastRunStatus,
      LastRunRag,
      RunCriticality,
      @Aggregation.default: #SUM
      OpenExceptions,
      Status,
      StatusCriticality,
      StaleAfterMinutes,
      AgeMinutes,
      IsStale,
      StaleCriticality,
      PlannedDowntimeWindows,
      IsPlannedDowntime,
      @Aggregation.default: #SUM
      SliceCount,
      @Aggregation.default: #SUM
      FlaggedCount,
      @Aggregation.default: #SUM
      CheckCount,
      @Aggregation.default: #SUM
      StaleCount,
      IsAttention
}

// Artifact: zc_ca_opscheckstatus.ddls.asddls
// Purpose: Consumption view of the area dashboard (service ZUI_CA_OPS_DASH, list report "Checks by area"):
//          per area, registered check and company-code slice - process, last run, status, open exceptions,
//          freshness. Read access: DCL ZC_CA_OPSCHECKSTATUS (ZCA_OPS 03 for the area and, for a company-code
//          slice, its BUKRS). Read-only.
// Modification log: 2026-11-10 | Initial version (process onboarding: area dashboard and freshness).
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
      CheckName,
      ScheduleGroup,
      ClassName,
      IsCompanyCodeAware,
      LastRunId,
      LastRunAt,
      LastRunStatus,
      LastRunRag,
      RunCriticality,
      OpenExceptions,
      Status,
      StatusCriticality,
      StaleAfterMinutes,
      AgeMinutes,
      IsStale,
      StaleCriticality,
      SliceCount,
      FlaggedCount
}

// Artifact: zc_ca_opscatalogue.ddls.asddls
// Purpose: Consumption view of the process catalogue with today's activation (service ZUI_CA_OPS_DASH, list
//          "Process catalogue": what is active, since when, why, approved by whom, and whether it is
//          monitored). Read access: DCL ZC_CA_OPSCATALOGUE (ZCA_OPS 03 for the framework area CA_OPS - the
//          catalogue is product configuration, no business data). Read-only.
// Modification log: 2026-11-11 | Initial version (process catalogue with activation).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Process catalogue with activation'
@Metadata.allowExtensions: true
@Search.searchable: true
define root view entity ZC_CA_OpsCatalogue
  provider contract transactional_query
  as projection on ZR_CA_OpsCatalogue
{
      @Search.defaultSearchElement: true
  key ProcessId,
      PackageId,
      PackageKind,
      PackageName,
      @Search.defaultSearchElement: true
      ProcessName,
      Component,
      DashboardCard,
      OwnerRole,
      Schedule,
      Evidence,
      VerifyRef,
      IsDefaultActive,
      IsActive,
      ActiveCriticality,
      ActivationSource,
      ActiveFrom,
      ActivationReason,
      ApprovedBy,
      MonitoringChecks,
      Seq
}

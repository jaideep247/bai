// Artifact: zc_ca_opsprocstatus.ddls.asddls
// Purpose: Consumption view of the active business processes (service ZUI_CA_OPS_DASH, list "Business processes"
//          and a consumer's overview card "Active business processes" with the KPIs of each process; annotations
//          in the metadata extension). Read access: DCL ZC_CA_OPSPROCSTATUS (ZCA_OPS 03 for the area and, for a
//          company-code slice, its BUKRS). Read-only.
// Modification log: 2026-11-11 | Initial version (process catalogue with activation).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Dashboard: active business processes'
@Metadata.allowExtensions: true
@Search.searchable: true
define root view entity ZC_CA_OpsProcStatus
  provider contract transactional_query
  as projection on ZR_CA_OpsProcStatus
{
      @Search.defaultSearchElement: true
  key Area,
      @Search.defaultSearchElement: true
  key ProcessId,
  key CompanyCode,
      @Search.defaultSearchElement: true
      ProcessName,
      CatalogueProcess,
      CatalogueName,
      Component,
      DashboardCard,
      OwnerRole,
      Schedule,
      ActiveFrom,
      ActivationReason,
      @Aggregation.default: #SUM
      CheckCount,
      @Aggregation.default: #SUM
      FlaggedCount,
      @Aggregation.default: #SUM
      StaleCount,
      @Aggregation.default: #SUM
      OpenExceptions,
      Status,
      StatusCriticality,
      IsUnmonitored,
      IsAttention,
      @Aggregation.default: #SUM
      ProcessCount
}

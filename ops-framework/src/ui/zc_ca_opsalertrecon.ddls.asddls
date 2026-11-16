// Artifact: zc_ca_opsalertrecon.ddls.asddls
// Purpose: Consumption view of the alert reconciliation (service ZUI_CA_OPS_DASH, list "Alert reconciliation"):
//          per run, findings that should have alerted versus alerts submitted versus alerts delivered; annotations in
//          the metadata extension. Read access: DCL ZC_CA_OPSALERTRECON (ZCA_OPS 03 for the area of the run).
//          Read-only.
// Modification log: 2026-11-16 | Initial version (build O: alert delivery reconciliation).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Alert reconciliation per run'
@Metadata.allowExtensions: true
define root view entity ZC_CA_OpsAlertRecon
  provider contract transactional_query
  as projection on ZR_CA_OpsAlertRecon
{
  key RunId,
      Area,
      Variant,
      StartedAt,
      RunRag,
      @Aggregation.default: #SUM
      ExceptionCount,
      @Aggregation.default: #SUM
      BlockingCount,
      @Aggregation.default: #SUM
      DecisionCount,
      @Aggregation.default: #SUM
      SubmittedCount,
      @Aggregation.default: #SUM
      DeliveredCount,
      @Aggregation.default: #SUM
      PendingCount,
      @Aggregation.default: #SUM
      CannotConfirmCount,
      @Aggregation.default: #SUM
      DeliveryFailedCount,
      @Aggregation.default: #SUM
      SubmitFailedCount,
      @Aggregation.default: #SUM
      SuppressedCount,
      @Aggregation.default: #SUM
      ClaimedCount,
      ReconState,
      ReconCriticality
}

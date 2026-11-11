// Artifact: zc_ca_opshandover.ddls.asddls
// Purpose: Consumption view of the shift handover (service ZUI_CA_OPS_HOVR, list report "Shift handover"; also
//          exposed by a consumer's overview page for the card "Shift handover"): counters summed over the rows the
//          user may read. Read access: DCL ZC_CA_OPSHANDOVER (company-code rule of docs/auth_zca_ops.md section 3c).
//          Read-only.
// Modification log: 2026-11-11 | Initial version (operations response features: shift handover).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Shift handover'
@Metadata.allowExtensions: true
define root view entity ZC_CA_OpsHandover
  provider contract transactional_query
  as projection on ZR_CA_OpsHandover
{
  key Team,
  key Area,
  key CompanyCode,
      SinceUtc,
      SinceDate,
      SinceTime,
      ShiftStartTime,
      NextShiftTime,
      TimeZone,
      @Aggregation.default: #SUM
      NewExceptions,
      @Aggregation.default: #SUM
      ResolvedExceptions,
      @Aggregation.default: #SUM
      OpenExceptions,
      @Aggregation.default: #SUM
      Escalations,
      @Aggregation.default: #SUM
      ControlsAwaitingSignOff,
      @Aggregation.default: #SUM
      DowntimeActive,
      @Aggregation.default: #SUM
      DowntimeNextShift,
      IsAttention,
      AttentionCriticality
}

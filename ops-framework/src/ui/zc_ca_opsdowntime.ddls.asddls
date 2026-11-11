// Artifact: zc_ca_opsdowntime.ddls.asddls
// Purpose: Consumption view of the downtime app (list report "Planned downtime", service ZUI_CA_OPS_DTW):
//          windows with their derived status, scope, start and end (local, the window's time zone), reason,
//          planner and approver. Read access: DCL ZC_CA_OPSDOWNTIME (ZCA_OPS 03 for the area); plan 01, change /
//          delete / End now 02, approve 85 (behaviour pool). Search by reason or area.
// Modification log: 2026-11-11 | Initial version (operations response features: planned downtime).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Planned downtime windows'
@Metadata.allowExtensions: true
@Search.searchable: true
define root view entity ZC_CA_OpsDowntime
  provider contract transactional_query
  as projection on ZR_CA_OpsDowntime
{
  key WindowId,
      @Search.defaultSearchElement: true
      Area,
      CheckPattern,
      ObjectPattern,
      GroupPattern,
      FromDate,
      FromTime,
      ToDate,
      ToTime,
      TimeZone,
      FromUtc,
      ToUtc,
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      Reason,
      CreatedBy,
      CreatedAt,
      ApprovedBy,
      ApprovedAt,
      EndedBy,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      @ObjectModel.text.element: [ 'WindowStatusText' ]
      WindowStatus,
      _StatusText.StatusText as WindowStatusText : localized,
      StatusCriticality,
      _StatusText
}

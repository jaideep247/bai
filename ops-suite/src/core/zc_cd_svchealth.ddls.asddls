// Artifact: zc_cd_svchealth.ddls.asddls
// Purpose: Consumption view of the service health score (overview page, entity ServiceHealth): score 0-100, rating,
//          open problems and stale monitors per business service, business date and company-code slice. Read
//          access: DCL ZC_CD_OPSOVERVIEW (area CD_OPS; company code blank = area-level slice, else the company code
//          must be authorised). Read-only.
// Modification log: 2026-11-11 | Initial version (service health score of the overview page).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Production support - service health'
@Metadata.allowExtensions: true
define root view entity ZC_CD_SvcHealth
  provider contract transactional_query
  as projection on ZR_CD_SvcHealth
{
      @ObjectModel.text.element: [ 'ServiceName' ]
  key Service,
  key BusinessDate,
  key CompanyCode,
      @Semantics.text: true
      ServiceName,
      ServiceSequence,
      PaymentEngineArea,
      IsCurrentDay,
      OpenProblems,
      StaleMonitors,
      Points,
      Score,
      ScoreCriticality
}

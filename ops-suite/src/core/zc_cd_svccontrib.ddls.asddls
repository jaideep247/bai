// Artifact: zc_cd_svccontrib.ddls.asddls
// Purpose: Consumption view of the worst contributors of the service health score (overview page, entity
//          ServiceContributor). Read access: DCL ZC_CD_OPSOVERVIEW (area of the findings and company code).
// Modification log: 2026-11-11 | Initial version (service health score of the overview page).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Production support - service health causes'
@Metadata.allowExtensions: true
define root view entity ZC_CD_SvcContrib
  provider contract transactional_query
  as projection on ZR_CD_SvcContrib
{
      @ObjectModel.text.element: [ 'ServiceName' ]
  key Service,
  key BusinessDate,
  key CompanyCode,
  key Area,
  key CheckCode,
      @Semantics.text: true
      ServiceName,
      PaymentEngineArea,
      IsCurrentDay,
      @Aggregation.default: #SUM
      Problems,
      @Aggregation.default: #SUM
      Points
}

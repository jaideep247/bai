// Artifact: zi_cd_svcpts.ddls.asddls
// Purpose: Service health - points and open problems per service, business date and company-code slice (blank =
//          area-level problems). Additive: the score of a slice adds the area-level points (ZR_CD_SvcHealth).
// Modification log: 2026-11-11 | Initial version (service health score of the overview page).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Service health - points per slice'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #M, dataClass: #TRANSACTIONAL }
define view entity ZI_CD_SvcPts
  as select from ZI_CD_SvcObj
{
  key Service,
  key BusinessDate,
  key CompanyCode,
      cast( sum( Points ) as abap.int4 )                    as Points,
      cast( count( * ) as abap.int4 )                       as Problems
}
group by
  Service,
  BusinessDate,
  CompanyCode

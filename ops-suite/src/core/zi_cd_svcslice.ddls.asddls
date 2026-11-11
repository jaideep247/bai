// Artifact: zi_cd_svcslice.ddls.asddls
// Purpose: Service health - the rows of the card: every active business service on every business date of the
//          control review (ZI_CA_OpsBusDay, 31 days) as the area-level slice (company code blank - so a service
//          without problems shows 100), plus one slice per company code that has problems of the service on the
//          date (ZI_CD_SvcPts). Read-only.
// Modification log: 2026-11-11 | Initial version (service health score of the overview page).
// VERIFY-ADT: CROSS JOIN and UNION in a CDS view entity (7.58).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Service health - slices'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #M, dataClass: #TRANSACTIONAL }
define view entity ZI_CD_SvcSlice
  as select from zcd_ops_svc     as Svc
    cross join   ZI_CA_OpsBusDay as Day
{
  key Svc.service                                           as Service,
  key Day.BusinessDate,
  key cast( ' ' as bukrs )                                  as CompanyCode
}
where
  Svc.active = 'X'

union

select from ZI_CD_SvcPts as Pts
{
  key Pts.Service,
  key Pts.BusinessDate,
  key cast( Pts.CompanyCode as bukrs )                      as CompanyCode
}
where
  Pts.CompanyCode <> ' '

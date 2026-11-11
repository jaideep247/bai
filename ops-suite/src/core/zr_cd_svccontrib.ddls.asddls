// Artifact: zr_cd_svccontrib.ddls.asddls
// Purpose: Worst contributors of the service health score: per business service, business date, company code
//          (blank = area-level), area and check code - the open problems and the points they take (ZI_CD_SvcObj).
//          The card lists the largest first. Read-only.
// Modification log: 2026-11-11 | Initial version (service health score of the overview page).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Production support - service health causes'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #M, dataClass: #TRANSACTIONAL }
define root view entity ZR_CD_SvcContrib
  as select from    ZI_CD_SvcObj    as Obj
    inner join      zcd_ops_svc     as Svc on Svc.service = Obj.Service
    left outer join ZI_CA_OpsBusDay as Day on Day.BusinessDate = Obj.BusinessDate
{
  key Obj.Service,
  key Obj.BusinessDate,
  key Obj.CompanyCode,
  key Obj.Area,
  key Obj.CheckCode,
      Svc.label                                             as ServiceName,
      cast( 'CD_OPS' as abap.char( 16 ) )                   as PaymentEngineArea,
      cast( case when Day.IsCurrentDay = 'X' then 'X' else ' ' end as abap_boolean ) as IsCurrentDay,
      cast( count( * ) as abap.int4 )                       as Problems,
      cast( sum( Obj.Points ) as abap.int4 )                as Points
}
group by
  Obj.Service,
  Obj.BusinessDate,
  Obj.CompanyCode,
  Obj.Area,
  Obj.CheckCode,
  Svc.label,
  Day.IsCurrentDay

// Artifact: zr_cd_svchealth.ddls.asddls
// Purpose: "Service health" card of the overview page: a score 0-100 per business service (ZCD_OPS_SVC), business
//          date and company-code slice. Score = 100 - points, at least 0: points of the area-level problems of the
//          service (company code blank) + points of the slice's company code (non-blank slice only) + stale points
//          of its monitors (current business date only). Rating from the bands of the service: 3 good (score >=
//          GREEN_MIN), 2 watch (>= AMBER_MIN), 1 critical. Company-code isolation (decision, Dashboard_Production_
//          Support.md section 1c): a score is not additive, so it is never summed over company codes - every row
//          is complete for its slice (area-level + one company code) and the DCL shows a user only the slices of his
//          company codes; a central user sees the area-level row and each company code with problems. Live: nothing
//          is stored. Read-only.
// Modification log: 2026-11-11 | Initial version (service health score of the overview page).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Production support - service health'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #M, dataClass: #TRANSACTIONAL }
define root view entity ZR_CD_SvcHealth
  as select from    ZI_CD_SvcSlice  as Slice
    inner join      zcd_ops_svc     as Svc   on  Svc.service       = Slice.Service
    left outer join ZI_CD_SvcPts    as Lvl   on  Lvl.Service       = Slice.Service
                                             and Lvl.BusinessDate  = Slice.BusinessDate
                                             and Lvl.CompanyCode   = ' '
    left outer join ZI_CD_SvcPts    as Own   on  Own.Service       = Slice.Service
                                             and Own.BusinessDate  = Slice.BusinessDate
                                             and Own.CompanyCode   = Slice.CompanyCode
                                             and Own.CompanyCode   <> ' '
    left outer join ZI_CA_OpsBusDay as Day   on  Day.BusinessDate  = Slice.BusinessDate
    left outer join ZI_CD_SvcStaleS as Stale on  Stale.Service     = Slice.Service
                                             and Day.IsCurrentDay  = 'X'
{
  key Slice.Service,
  key Slice.BusinessDate,
  key Slice.CompanyCode,
      Svc.label                                             as ServiceName,
      Svc.seq                                               as ServiceSequence,
      cast( 'CD_OPS' as abap.char( 16 ) )                   as PaymentEngineArea,
      cast( case when Day.IsCurrentDay = 'X' then 'X' else ' ' end as abap_boolean ) as IsCurrentDay,
      cast( coalesce( Lvl.Problems, 0 ) + coalesce( Own.Problems, 0 ) as abap.int4 ) as OpenProblems,
      cast( coalesce( Stale.StaleMonitors, 0 ) as abap.int4 ) as StaleMonitors,
      cast( coalesce( Lvl.Points, 0 ) + coalesce( Own.Points, 0 ) + coalesce( Stale.StalePoints, 0 )
            as abap.int4 )                                  as Points,
      cast( case when coalesce( Lvl.Points, 0 ) + coalesce( Own.Points, 0 ) + coalesce( Stale.StalePoints, 0 ) >= 100
                 then 0
                 else 100 - coalesce( Lvl.Points, 0 ) - coalesce( Own.Points, 0 ) - coalesce( Stale.StalePoints, 0 )
                 end as abap.int4 )                         as Score,
      cast( case when 100 - coalesce( Lvl.Points, 0 ) - coalesce( Own.Points, 0 ) - coalesce( Stale.StalePoints, 0 )
                      >= Svc.green_min then 3
                 when 100 - coalesce( Lvl.Points, 0 ) - coalesce( Own.Points, 0 ) - coalesce( Stale.StalePoints, 0 )
                      >= Svc.amber_min then 2
                 else 1 end as abap.int1 )                  as ScoreCriticality
}

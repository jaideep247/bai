// Artifact: zr_cd_hckcategory.ddls.asddls
// Purpose: Scorecard per category (A financial integrity ... E technical health) of the health
//          check dashboard: active checks and their status counts in the last completed run
//          (ZR_CD_HckCheck), category status = worst check (RED, AMBER, GREEN; GREY when no check
//          of the category has a verdict - warm-up or no result), open exceptions. Drill-down:
//          category -> checks. Read-only.
// Modification log: 2026-11-06 | Initial version (health check dashboard).
//                   2026-11-10 | Company-code isolation: per category and check slice (key CompanyCode) - the counts of a company code
//                                are summed only into its own row.
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'HCK health check dashboard - category'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #S, dataClass: #MIXED }
define root view entity ZR_CD_HckCategory
  as select from ZR_CD_HckCheck
  association [0..*] to ZR_CD_HckCheck as _Checks on  $projection.Category    = _Checks.Category
                                                  and $projection.CompanyCode = _Checks.CompanyCode
{
  key Category,
  key CompanyCode,
      CategoryText,
      PaymentEngineArea,
      AsOfRunId,
      AsOfAt,
      MonitorAgeMinutes,
      MonitorIsStale,
      MonitorCriticality,
      cast( case
              when sum( RedCheckCount ) > 0   then 'RED'
              when sum( AmberCheckCount ) > 0 then 'AMBER'
              when sum( GreenCheckCount ) > 0 then 'GREEN'
              else 'GREY' end as abap.char( 10 ) )          as CategoryStatus,
      cast( case
              when sum( RedCheckCount ) > 0   then 1
              when sum( AmberCheckCount ) > 0 then 2
              when sum( GreenCheckCount ) > 0 then 3
              else 0 end as abap.int1 )                     as StatusCriticality,
      cast( sum( CheckCount ) as abap.int4 )                as CheckCount,
      cast( sum( RedCheckCount ) as abap.int4 )             as RedCheckCount,
      cast( sum( AmberCheckCount ) as abap.int4 )           as AmberCheckCount,
      cast( sum( GreenCheckCount ) as abap.int4 )           as GreenCheckCount,
      cast( sum( WarmupCheckCount ) as abap.int4 )          as WarmupCheckCount,
      cast( sum( NoResultCheckCount ) as abap.int4 )        as NoResultCheckCount,
      cast( sum( OpenFindingCount ) as abap.int4 )          as OpenFindingCount,
      _Checks
}
group by
  Category,
  CompanyCode,
  CategoryText,
  PaymentEngineArea,
  AsOfRunId,
  AsOfAt,
  MonitorAgeMinutes,
  MonitorIsStale,
  MonitorCriticality

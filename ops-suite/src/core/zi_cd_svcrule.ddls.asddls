// Artifact: zi_cd_svcrule.ddls.asddls
// Purpose: Service health - what each active business service covers, as finding rules: the area of the findings,
//          the finding field (AREA = every finding of the area, RULE_ID, CHECK_CODE, GROUP2) and the exact value,
//          with the weight of the mapping row. A CONTROL row is expanded into the covered-check rows of that control
//          (ZCA_OPS_CTLCHK - the same exact values the daily review uses), so a service follows its controls without
//          repeating their checks. Exact values only: CDS cannot apply a pattern held in a column, and SQL never
//          receives a pattern (DEVELOPMENT_STANDARDS.md section 2). Read-only.
// Modification log: 2026-11-11 | Initial version (service health score of the overview page).
// VERIFY-ADT: UNION ALL with literal elements in a CDS view entity (7.58).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Service health - finding rules per service'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #A, sizeCategory: #S, dataClass: #CUSTOMIZING }
define view entity ZI_CD_SvcRule
  as select from zcd_ops_svcmap as Map
    inner join   zcd_ops_svc    as Svc on  Svc.service = Map.service
                                       and Svc.active  = 'X'
{
  key Map.service                                           as Service,
  key cast( Map.area as abap.char( 16 ) )                   as CheckArea,
  key cast( Map.match_field as abap.char( 10 ) )            as MatchField,
  key cast( Map.match_value as abap.char( 40 ) )            as MatchValue,
      Map.weight                                            as Weight
}
where
      Map.active      =  'X'
  and Map.match_field <> 'CONTROL'

union all

select from zcd_ops_svcmap  as Map
  inner join zcd_ops_svc    as Svc on  Svc.service    = Map.service
                                   and Svc.active     = 'X'
  inner join zca_ops_ctlchk as Chk on  Chk.area       = Map.area
                                   and Chk.control_id = Map.match_value
{
  key Map.service                                           as Service,
  key cast( Chk.check_area as abap.char( 16 ) )             as CheckArea,
  key cast( Chk.match_field as abap.char( 10 ) )            as MatchField,
  key cast( Chk.match_value as abap.char( 40 ) )            as MatchValue,
      Map.weight                                            as Weight
}
where
      Map.active      = 'X'
  and Map.match_field = 'CONTROL'

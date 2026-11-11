// Artifact: zi_cd_svcfind.ddls.asddls
// Purpose: Service health - live findings a business service is charged with, per business date: the findings
//          (ZCA_OPS_FINDING) of the runs of the date (ZI_CA_OpsCtlRunDay, local date of CONTROL_TIME_ZONE) of the
//          rule's area that match a rule of the service (ZI_CD_SvcRule: every finding of the area, or RULE_ID /
//          CHECK_CODE / GROUP2 equal to the value). Live = open, assigned or superseded - the rule of the daily
//          control review (ZI_CA_OpsCtlFind): resolved and waived findings do not count. Points = the severity
//          points of the service (B / E / W; information 0) x the weight of the rule. Company code of the finding
//          (blank = area-level). Read-only.
// Modification log: 2026-11-11 | Initial version (service health score of the overview page).
// VERIFY-ADT: OR of field comparisons in the ON condition of an inner join (7.58), as ZI_CA_OpsCtlFind.
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Service health - findings per service'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define view entity ZI_CD_SvcFind
  as select from ZI_CD_SvcRule      as Rule
    inner join   zcd_ops_svc        as Svc on  Svc.service = Rule.Service
    inner join   ZI_CA_OpsCtlRunDay as Run on  Run.Area    = Rule.CheckArea
    inner join   zca_ops_finding    as Fnd on  Fnd.run_id  = Run.RunId
                                           and (    Rule.MatchField = 'AREA'
                                                 or ( Rule.MatchField = 'RULE_ID'    and Fnd.rule_id    = Rule.MatchValue )
                                                 or ( Rule.MatchField = 'CHECK_CODE' and Fnd.check_code = Rule.MatchValue )
                                                 or ( Rule.MatchField = 'GROUP2'     and Fnd.group2     = Rule.MatchValue ) )
{
  key Rule.Service,
  key Rule.MatchField,
  key Rule.MatchValue,
  key Fnd.run_id                                            as RunId,
  key Fnd.finding_no                                        as FindingNo,
      Run.BusinessDate,
      Fnd.bukrs                                             as CompanyCode,
      cast( Fnd.area as abap.char( 16 ) )                   as Area,
      Fnd.check_code                                        as CheckCode,
      Fnd.object_key                                        as ObjectKey,
      Fnd.severity                                          as Severity,
      cast( case Fnd.severity when 'B' then Svc.weight_b
                              when 'E' then Svc.weight_e
                              when 'W' then Svc.weight_w
                              else 0 end * Rule.Weight as abap.int4 ) as Points
}
where
     Fnd.disposition = 'O'
  or Fnd.disposition = 'A'
  or Fnd.disposition = 'S'

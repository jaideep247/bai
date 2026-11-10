// Artifact: zi_ca_opsctlfind.ddls.asddls
// Purpose: Live findings of the checks a control covers, per business date: findings (ZCA_OPS_FINDING) of
//          the runs of the date (ZI_CA_OpsCtlRunDay) whose RULE_ID, CHECK_CODE or GROUP2 equals a covered-
//          check row of the control (ZCA_OPS_CTLCHK, exact value, area of the findings). Live = open,
//          assigned or superseded (raised again by a later run): a finding resolved (also by a later run
//          that no longer raised it - the latest result of the date decides) or waived does not count.
//          Status rank of a finding: B / E 2 (action required), W 1 (watch), else 0 (healthy) - the rule of
//          ZCL_CA_OPS_REVIEW_POLICY=>STATUS_OF_SEVERITY. Read-only.
// Modification log: 2026-11-10 | Initial version (control register and daily control review).
// VERIFY-ADT: OR of field comparisons in the ON condition of an inner join (7.58); PlanViz: findings read by
//             RUN_ID (primary key) of the runs of the date (CTL-08).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Control review: findings of a control'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define view entity ZI_CA_OpsCtlFind
  as select from zca_ops_ctlchk     as Chk
    inner join   ZI_CA_OpsCtlRunDay as Run on Run.Area = Chk.check_area
    inner join   zca_ops_finding    as Fnd on  Fnd.run_id = Run.RunId
                                           and (    ( Chk.match_field = 'RULE_ID'    and Fnd.rule_id    = Chk.match_value )
                                                 or ( Chk.match_field = 'CHECK_CODE' and Fnd.check_code = Chk.match_value )
                                                 or ( Chk.match_field = 'GROUP2'     and Fnd.group2     = Chk.match_value ) )
{
  key Chk.area                                              as Area,
  key Chk.control_id                                        as ControlId,
  key Chk.match_field                                       as MatchField,
  key Chk.match_value                                       as MatchValue,
  key Fnd.run_id                                            as RunId,
  key Fnd.finding_no                                        as FindingNo,
      Run.BusinessDate,
      Fnd.severity                                          as Severity,
      Fnd.disposition                                       as Disposition,
      Fnd.created_at                                        as CreatedAt,
      cast( case when Fnd.severity = 'B' or Fnd.severity = 'E' then 2
                 when Fnd.severity = 'W' then 1
                 else 0 end as abap.int4 )                  as StatusRank
}
where
     Fnd.disposition = 'O'
  or Fnd.disposition = 'A'
  or Fnd.disposition = 'S'

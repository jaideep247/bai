// Artifact: zi_ca_opsctleval.ddls.asddls
// Purpose: Evaluation of the checks a control covers on a business date (build O, docs/EVALUATION_AND_COVERAGE.md
//          section 3): the covered checks of an active control (GROUP2 rows of ZCA_OPS_CTLCHK = check IDs) that are
//          in effect today (ZI_CA_OpsChkEff), and of them those whose latest evaluation of the date is unknown - not
//          evaluated, stale or partial - or that have no evaluation of the date at all (not run). A control with
//          unknown covered checks is never signed off as healthy without an observation (ZCL_CA_OPS_REVIEW_POLICY,
//          message 567). Rows that select findings by RULE_ID / CHECK_CODE name no check and are not counted.
//          Nothing stored, read-only.
// Modification log: 2026-11-16 | Initial version (build O: evaluation state of every control).
// VERIFY-ADT (V279): CROSS JOIN with ZI_CA_OpsBusDay and a left outer join on a grouped view (7.58); the comparison
//             of MATCH_VALUE (CHAR 35) with CHECK_ID (CHAR 20).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Control review: evaluation of checks'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #M, dataClass: #MIXED }
define view entity ZI_CA_OpsCtlEval
  as select from    zca_ops_ctlchk   as Cc
    inner join      zca_ops_control  as Ctl on  Ctl.area       = Cc.area
                                            and Ctl.control_id = Cc.control_id
    inner join      ZI_CA_OpsChkEff  as Eff on  Eff.Area    = Cc.check_area
                                            and Eff.CheckId = Cc.match_value
    cross join      ZI_CA_OpsBusDay  as Day
    left outer join ZI_CA_OpsEvalDay as Ed  on  Ed.Area         = Cc.check_area
                                            and Ed.CheckId      = Cc.match_value
                                            and Ed.BusinessDate = Day.BusinessDate
    left outer join zca_ops_eval     as Ev  on  Ev.area         = Ed.Area
                                            and Ev.check_id     = Ed.CheckId
                                            and Ev.evaluated_at = Ed.LastEvaluatedAt
{
  key Cc.area                                               as Area,
  key Cc.control_id                                         as ControlId,
  key Day.BusinessDate                                      as BusinessDate,
      cast( count( * ) as abap.int4 )                       as CoveredChecks,
      cast( sum( case when Ev.eval_state is null then 1
                      when Ev.eval_state = 'NOT_EVAL' or Ev.eval_state = 'STALE' or Ev.eval_state = 'PARTIAL'
                        or Ev.eval_state = ' ' then 1
                      else 0 end ) as abap.int4 )           as UnknownChecks,
      cast( sum( case when Ev.eval_state is null then 1 else 0 end ) as abap.int4 ) as NotRunChecks
}
where
      Ctl.active      = 'X'
  and Cc.match_field  = 'GROUP2'
group by
  Cc.area,
  Cc.control_id,
  Day.BusinessDate

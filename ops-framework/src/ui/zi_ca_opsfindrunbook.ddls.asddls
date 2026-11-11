// Artifact: zi_ca_opsfindrunbook.ddls.asddls
// Purpose: Runbook link and first action of a finding (ZCA_OPS_RUNBOOK, active rows of the finding's area, exact
//          values): the row of its CHECK_CODE, else of its GROUP2 (check of the registry), else of its RULE_ID -
//          the rule of ZCL_CA_OPS_ALERT_POLICY=>RUNBOOK_FOR (alert e-mail). One row per finding (key run and
//          finding number), blank link when no row applies. Used by the exceptions app and available to any
//          app or card that shows findings (association by RunId / FindingNo). Read-only; the reading entity's
//          DCL decides who sees the finding.
// Modification log: 2026-11-11 | Initial version (operations response features: runbook link per check).
// VERIFY-ADT: left outer joins with a literal in the ON condition and coalesce over their columns (7.58).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Runbook link of a finding'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define view entity ZI_CA_OpsFindRunbook
  as select from    zca_ops_finding as Fnd
    left outer join zca_ops_runbook as Chk on  Chk.area        = Fnd.area
                                           and Chk.match_field = 'CHECK_CODE'
                                           and Chk.match_value = Fnd.check_code
                                           and Chk.active      = 'X'
    left outer join zca_ops_runbook as Grp on  Grp.area        = Fnd.area
                                           and Grp.match_field = 'GROUP2'
                                           and Grp.match_value = Fnd.group2
                                           and Grp.active      = 'X'
    left outer join zca_ops_runbook as Rul on  Rul.area        = Fnd.area
                                           and Rul.match_field = 'RULE_ID'
                                           and Rul.match_value = Fnd.rule_id
                                           and Rul.active      = 'X'
{
  key Fnd.run_id                                            as RunId,
  key Fnd.finding_no                                        as FindingNo,
      Fnd.area                                              as Area,
      @EndUserText.label: 'Runbook'
      cast( coalesce( Chk.runbook_url, coalesce( Grp.runbook_url, Rul.runbook_url ) ) as abap.char( 255 ) )
                                                            as RunbookUrl,
      @EndUserText.label: 'First action'
      cast( coalesce( Chk.first_action, coalesce( Grp.first_action, Rul.first_action ) ) as abap.char( 120 ) )
                                                            as FirstAction,
      // Which row applied: CHECK_CODE, GROUP2 or RULE_ID (blank = none)
      cast( case when Chk.match_value is not null then 'CHECK_CODE'
                 when Grp.match_value is not null then 'GROUP2'
                 when Rul.match_value is not null then 'RULE_ID'
                 else ' ' end as abap.char( 10 ) )          as MatchField
}

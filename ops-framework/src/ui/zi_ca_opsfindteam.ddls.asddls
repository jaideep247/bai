// Artifact: zi_ca_opsfindteam.ddls.asddls
// Purpose: Team of a finding (any row, also superseded ones - an escalation names the row it escalated): the
//          owner team of its CHECK_CODE, else of its GROUP2, else of its RULE_ID (ZI_CA_OpsCheckTeam, the
//          precedence of the runbook link); blank = no control covers the check. Read-only.
// Modification log: 2026-11-11 | Initial version (operations response features: metrics and shift handover).
// VERIFY-ADT: left outer joins with a literal in the ON condition and coalesce over their columns (7.58).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Team of a finding'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define view entity ZI_CA_OpsFindTeam
  as select from    zca_ops_finding    as Fnd
    left outer join ZI_CA_OpsCheckTeam as Chk on  Chk.CheckArea  = Fnd.area
                                              and Chk.MatchField = 'CHECK_CODE'
                                              and Chk.MatchValue = Fnd.check_code
    left outer join ZI_CA_OpsCheckTeam as Grp on  Grp.CheckArea  = Fnd.area
                                              and Grp.MatchField = 'GROUP2'
                                              and Grp.MatchValue = Fnd.group2
    left outer join ZI_CA_OpsCheckTeam as Rul on  Rul.CheckArea  = Fnd.area
                                              and Rul.MatchField = 'RULE_ID'
                                              and Rul.MatchValue = Fnd.rule_id
{
  key Fnd.run_id                                            as RunId,
  key Fnd.finding_no                                        as FindingNo,
      cast( coalesce( Chk.Team, coalesce( Grp.Team, Rul.Team ) ) as abap.char( 10 ) ) as Team
}

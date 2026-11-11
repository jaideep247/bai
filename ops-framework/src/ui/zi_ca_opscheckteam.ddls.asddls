// Artifact: zi_ca_opscheckteam.ddls.asddls
// Purpose: Owner team of a check: the team of the active controls (ZCA_OPS_CONTROL-TEAM, values of CONTROL_TEAMS)
//          that cover it (ZCA_OPS_CTLCHK: area of the findings, RULE_ID / CHECK_CODE / GROUP2, exact value). A
//          check covered by controls of two teams gets the first team in alphabetical order. Checks no control
//          covers have no team ("where known"). Read-only.
// Modification log: 2026-11-11 | Initial version (operations response features: metrics and shift handover).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Owner team of a check (control register)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #A, sizeCategory: #S, dataClass: #CUSTOMIZING }
define view entity ZI_CA_OpsCheckTeam
  as select from zca_ops_ctlchk  as Chk
    inner join   zca_ops_control as Ctl on  Ctl.area       = Chk.area
                                        and Ctl.control_id = Chk.control_id
{
  key Chk.check_area                                        as CheckArea,
  key Chk.match_field                                       as MatchField,
  key Chk.match_value                                       as MatchValue,
      min( Ctl.team )                                       as Team
}
where
      Ctl.active =  'X'
  and Ctl.team   <> ' '
group by
  Chk.check_area,
  Chk.match_field,
  Chk.match_value

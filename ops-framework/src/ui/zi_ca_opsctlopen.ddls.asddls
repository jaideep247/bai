// Artifact: zi_ca_opsctlopen.ddls.asddls
// Purpose: Open exceptions of the checks a control covers, now: open or assigned findings of severity B, E or
//          W (the exceptions of the exceptions app ZUI_CA_OPS_EXC) whose RULE_ID, CHECK_CODE or GROUP2
//          equals a covered-check row of the control - whatever run raised them. Index OPN of
//          ZCA_OPS_FINDING (AREA, DISPOSITION). Counted on the database, nothing stored. Read-only.
// Modification log: 2026-11-10 | Initial version (control register and daily control review).
//                   2026-11-10 | Company-code isolation: counted per company code of the exceptions (blank =
//                                area-level).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Control review: open exceptions'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #M, dataClass: #TRANSACTIONAL }
define view entity ZI_CA_OpsCtlOpen
  as select from zca_ops_ctlchk  as Chk
    inner join   zca_ops_finding as Fnd on  Fnd.area = Chk.check_area
                                        and (    ( Chk.match_field = 'RULE_ID'    and Fnd.rule_id    = Chk.match_value )
                                              or ( Chk.match_field = 'CHECK_CODE' and Fnd.check_code = Chk.match_value )
                                              or ( Chk.match_field = 'GROUP2'     and Fnd.group2     = Chk.match_value ) )
{
  key Chk.area                                              as Area,
  key Chk.control_id                                        as ControlId,
  key Fnd.bukrs                                             as CompanyCode,
      cast( count( * ) as abap.int4 )                       as OpenExceptions
}
where
  (
       Fnd.disposition = 'O'
    or Fnd.disposition = 'A'
  )
  and(
       Fnd.severity    = 'B'
    or Fnd.severity    = 'E'
    or Fnd.severity    = 'W'
  )
group by
  Chk.area,
  Chk.control_id,
  Fnd.bukrs

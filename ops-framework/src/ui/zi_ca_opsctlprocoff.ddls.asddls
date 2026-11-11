// Artifact: zi_ca_opsctlprocoff.ddls.asddls
// Purpose: Controls not expected in the daily review today (2026-11-11): every covered-check row of the control
//          (ZCA_OPS_CTLCHK) is a GROUP2 row of a check switched off by its business process
//          (ZI_CA_OpsChkProcOff). A control with one row of another kind (RULE_ID, CHECK_CODE) or one check in
//          effect stays expected. Read by ZI_CA_OpsCtlSlice. Nothing stored, read-only.
// Modification log: 2026-11-11 | Initial version (process catalogue with activation).
// VERIFY-ADT: HAVING with COUNT( * ) = SUM( CASE ... ) in a view entity; the comparison of MATCH_VALUE
//             (CHAR 35) with CHECK_ID (CHAR 20) in the ON condition (as ZI_CA_OpsChkSlice).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Controls of switched-off processes'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #A, sizeCategory: #S, dataClass: #CUSTOMIZING }
define view entity ZI_CA_OpsCtlProcOff
  as select from    zca_ops_ctlchk      as Cc
    left outer join ZI_CA_OpsChkProcOff as Off on  Off.Area    = Cc.check_area
                                               and Off.CheckId = Cc.match_value
{
  key Cc.area                                               as Area,
  key Cc.control_id                                         as ControlId,
      cast( count( * ) as abap.int4 )                       as CoveredRows
}
group by
  Cc.area,
  Cc.control_id
having
  count( * ) = sum( case when Cc.match_field = 'GROUP2' and Off.CheckId is not null then 1 else 0 end )

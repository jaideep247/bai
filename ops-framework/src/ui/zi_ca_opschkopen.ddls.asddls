// Artifact: zi_ca_opschkopen.ddls.asddls
// Purpose: Open exceptions of every check now, per area, check (GROUP2 = check ID, stamped by the generic
//          runner) and company code of the findings (blank = area-level): open or assigned findings of
//          severity B, E or W - the exceptions of the exceptions app ZUI_CA_OPS_EXC - with their count and
//          worst rank (2 = B / E, 1 = W; the ranks of ZIF_CA_OPS_CTL_TYPES=>GC_RANK). Index OPN of
//          ZCA_OPS_FINDING (AREA, DISPOSITION). Counted on the database, nothing stored; never across company
//          codes in one row (docs/auth_zca_ops.md section 3c). Read-only.
// Modification log: 2026-11-10 | Initial version (process onboarding: area dashboard and freshness).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Area dashboard: open exceptions per check'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define view entity ZI_CA_OpsChkOpen
  as select from zca_ops_finding as Fnd
{
  key Fnd.area                                              as Area,
  key Fnd.group2                                            as CheckId,
  key Fnd.bukrs                                             as CompanyCode,
      cast( count( * ) as abap.int4 )                       as OpenExceptions,
      max( case Fnd.severity when 'W' then 1 else 2 end )   as WorstRank
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
  Fnd.area,
  Fnd.group2,
  Fnd.bukrs

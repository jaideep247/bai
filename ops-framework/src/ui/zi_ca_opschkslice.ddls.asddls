// Artifact: zi_ca_opschkslice.ddls.asddls
// Purpose: The rows of the area dashboard (company-code isolation, docs/auth_zca_ops.md section 3c): one row
//          per active registered check with blank company code (the area-level slice: run telemetry,
//          freshness and the area-level exceptions) and one row per company code that has open exceptions of
//          the check now (its own count and status only). Union of keys only, nothing stored. Read-only.
// Modification log: 2026-11-10 | Initial version (process onboarding: area dashboard and freshness).
// VERIFY-ADT: UNION (distinct) with identical key elements and the cast of a literal to BUKRS (as
//             ZI_CA_OpsCtlSlice); the comparison of GROUP2 (CHAR 35) with CHECK_ID (CHAR 20) in the ON condition.
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Area dashboard: slices per company code'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #M, dataClass: #MIXED }
define view entity ZI_CA_OpsChkSlice
  as select from zca_ops_check as Chk
{
  key Chk.area                                              as Area,
  key Chk.check_id                                          as CheckId,
  key cast( ' ' as bukrs )                                  as CompanyCode
}
where
  Chk.active = 'X'

union

select from  ZI_CA_OpsChkOpen as Op
  inner join zca_ops_check    as Chk on  Chk.area     = Op.Area
                                     and Chk.check_id = Op.CheckId
{
  key Chk.area                                              as Area,
  key Chk.check_id                                          as CheckId,
  key Op.CompanyCode                                        as CompanyCode
}
where
      Chk.active     =  'X'
  and Op.CompanyCode <> ' '

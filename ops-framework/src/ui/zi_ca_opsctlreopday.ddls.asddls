// Artifact: zi_ca_opsctlreopday.ddls.asddls
// Purpose: Changes after the sign-off per slice (control, business date, company code): how many covered
//          findings are new, changed in severity, changed in amount or produced by another configuration version
//          since the slice was signed off (ZI_CA_OpsCtlReopen). Aggregated on the database, nothing stored; the
//          reason of a reopened sign-off is derived in ZI_CA_OpsCtlState. Read-only.
// Modification log: 2026-11-11 | Initial version (explainable, versioned results).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Control review: changes per slice'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #M, dataClass: #TRANSACTIONAL }
define view entity ZI_CA_OpsCtlReopDay
  as select from ZI_CA_OpsCtlReopen
{
  key Area,
  key ControlId,
  key BusinessDate,
  key CompanyCode,
      cast( sum( NewFlag ) as abap.int4 )                   as NewCount,
      cast( sum( StatusFlag ) as abap.int4 )                as StatusCount,
      cast( sum( AmountFlag ) as abap.int4 )                as AmountCount,
      cast( sum( ConfigFlag ) as abap.int4 )                as ConfigCount
}
group by
  Area,
  ControlId,
  BusinessDate,
  CompanyCode

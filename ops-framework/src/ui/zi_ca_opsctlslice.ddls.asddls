// Artifact: zi_ca_opsctlslice.ddls.asddls
// Purpose: The slices of the daily control review (company-code isolation, 2026-11-10): one row per active
//          control, business date of the review window and company code. The area-level slice (blank company
//          code) exists for every control and date - findings without a company code, the run evidence and
//          the sign-off of the area; a company-code slice exists where that company code has findings of the
//          control on the date, open exceptions of the control now, or a sign-off of the date. Each slice is
//          derived, shown and signed off on its own, so a reviewer authorised for one company code reads and
//          signs off only the findings of that company code (and the area-level ones). Union of keys only,
//          nothing stored. Read-only.
// Modification log: 2026-11-10 | Initial version (company-code isolation of the daily control review).
// VERIFY-ADT: UNION (distinct) of four branches with identical key elements in a CDS view entity and the cast
//             of a literal to the data element BUKRS (7.58); PlanViz: the business-date filter of the review app
//             reaches every branch (CTL-08).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Control review: slices per company code'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #M, dataClass: #MIXED }
define view entity ZI_CA_OpsCtlSlice
  as select from zca_ops_control as Ctl
    cross join   ZI_CA_OpsBusDay as Day
{
  key Ctl.area                                              as Area,
  key Ctl.control_id                                        as ControlId,
  key Day.BusinessDate                                      as BusinessDate,
  key cast( ' ' as bukrs )                                  as CompanyCode
}
where
  Ctl.active = 'X'

union

select from  ZI_CA_OpsCtlFindDay as Fd
  inner join zca_ops_control     as Ctl on  Ctl.area       = Fd.Area
                                        and Ctl.control_id = Fd.ControlId
  inner join ZI_CA_OpsBusDay     as Day on  Day.BusinessDate = Fd.BusinessDate
{
  key Fd.Area                                               as Area,
  key Fd.ControlId                                          as ControlId,
  key Fd.BusinessDate                                       as BusinessDate,
  key Fd.CompanyCode                                        as CompanyCode
}
where
      Ctl.active     =  'X'
  and Fd.CompanyCode <> ' '

union

select from  ZI_CA_OpsCtlOpen as Op
  inner join zca_ops_control  as Ctl on  Ctl.area       = Op.Area
                                     and Ctl.control_id = Op.ControlId
  cross join ZI_CA_OpsBusDay  as Day
{
  key Op.Area                                               as Area,
  key Op.ControlId                                          as ControlId,
  key Day.BusinessDate                                      as BusinessDate,
  key Op.CompanyCode                                        as CompanyCode
}
where
      Ctl.active     =  'X'
  and Op.CompanyCode <> ' '

union

select from  zca_ops_review  as Rev
  inner join zca_ops_control as Ctl on  Ctl.area       = Rev.area
                                    and Ctl.control_id = Rev.control_id
  inner join ZI_CA_OpsBusDay as Day on  Day.BusinessDate = Rev.business_date
{
  key Rev.area                                              as Area,
  key Rev.control_id                                        as ControlId,
  key Rev.business_date                                     as BusinessDate,
  key Rev.bukrs                                             as CompanyCode
}
where
      Ctl.active =  'X'
  and Rev.bukrs  <> ' '

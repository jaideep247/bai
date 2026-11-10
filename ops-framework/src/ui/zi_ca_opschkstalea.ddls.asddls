// Artifact: zi_ca_opschkstalea.ddls.asddls
// Purpose: Freshness threshold of the area dashboard per area: the parameters CHECK_STALE_MIN_<area> of area
//          CA_OPS (ZCA_PARAM) that a consumer delivers for its areas - the maintained value (row 1), else the
//          definition default; one row per defined area. CDS cannot call the parameter API, so the framework's
//          parameter tables are read directly with the API's resolution, read-only (the rule of
//          ZI_CA_OpsCtlTz). Areas without a definition use CHECK_STALE_MIN_DEFAULT (ZI_CA_OpsChkStaleD).
// Modification log: 2026-11-10 | Initial version (process onboarding: area dashboard and freshness).
// VERIFY-ADT: replace( ) on a key element and the CHAR -> INT4 cast of a parameter value (7.58).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Area dashboard: stale threshold per area'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_CA_OpsChkStaleA
  as select from    zca_param_def as Def
    left outer join zca_param_val as Val on  Val.area = Def.area
                                         and Val.name = Def.name
                                         and Val.numb = 1
{
      // CHECK_STALE_MIN_ZPE_OPS -> ZPE_OPS (the area: a parameter area of ZCA_PARAM)
  key cast( replace( Def.name, 'CHECK_STALE_MIN_', '' ) as abap.char( 16 ) ) as Area,
      // The framework validates the value type INT (MIN 1) on save, so the text is a number
      cast( case when Val.low is null or Val.low = ''
                 then Def.default_value
                 else Val.low end as abap.int4 )                              as StaleAfterMinutes
}
where
      Def.area =    'CA_OPS'
  and Def.name like 'CHECK_STALE_MIN_%'
  and Def.name <>   'CHECK_STALE_MIN_DEFAULT'

// Artifact: zi_ca_opsshiftdef.ddls.asddls
// Purpose: Shift start times per team: the parameters SHIFT_TIMES_<team> of area CA_OPS (kind S, value type TIME,
//          one row per start time HHMMSS, local time of SHIFT_TIME_ZONE) that a consumer delivers for its teams
//          (the teams of CONTROL_TEAMS), and SHIFT_TIMES_DEFAULT (team blank: teams without own times and
//          exceptions of no team; delivered 000000 = one shift a day from midnight). The maintained rows, else
//          the definition default. CDS cannot call the parameter API, so the framework's parameter tables are read
//          directly with the API's resolution, read-only (the rule of ZI_CA_OpsChkStaleA). Read-only.
// Modification log: 2026-11-11 | Initial version (operations response features: shift handover).
// VERIFY-ADT: SELECT DISTINCT in a view entity, replace( ) on a key element, CHAR -> TIMS cast of a parameter
//             value (the framework validates value type TIME on save: HHMMSS).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Shift handover: shift start times'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_CA_OpsShiftDef
  as select distinct from zca_param_def as Def
    left outer join       zca_param_val as Val on  Val.area = Def.area
                                               and Val.name = Def.name
{
      // SHIFT_TIMES_ONSITE -> ONSITE; SHIFT_TIMES_DEFAULT -> blank (the default shift)
  key cast( case when Def.name = 'SHIFT_TIMES_DEFAULT' then ' '
                 else replace( Def.name, 'SHIFT_TIMES_', '' ) end as abap.char( 10 ) ) as Team,
  key cast( substring( case when Val.low is null or Val.low = '' then Def.default_value
                            else Val.low end, 1, 6 ) as abap.tims ) as StartTime
}
where
      Def.area =    'CA_OPS'
  and Def.name like 'SHIFT_TIMES_%'

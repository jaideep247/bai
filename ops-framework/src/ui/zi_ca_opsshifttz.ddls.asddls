// Artifact: zi_ca_opsshifttz.ddls.asddls
// Purpose: Time zone of the shift start times of the shift handover: parameter SHIFT_TIME_ZONE of area CA_OPS
//          (ZCA_PARAM) - the maintained value (row 1), else the definition default, else UTC. Exactly one row (the
//          logon language row of I_Language). CDS cannot call the parameter API, so the framework's parameter
//          tables are read directly with the API's resolution, read-only (the rule of ZI_CA_OpsCtlTz).
// Modification log: 2026-11-11 | Initial version (operations response features: shift handover).
// VERIFY-ADT: as ZI_CA_OpsCtlTz (V27).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Shift handover: time zone (ZCA_PARAM)'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_CA_OpsShiftTz
  as select from    I_Language    as Lang
    left outer join zca_param_def as Def on  Def.area = 'CA_OPS'
                                         and Def.name = 'SHIFT_TIME_ZONE'
    left outer join zca_param_val as Val on  Val.area = Def.area
                                         and Val.name = Def.name
                                         and Val.numb = 1
{
  key Lang.Language                                         as Language,
      cast( case when Val.low is not null and Val.low <> ''
                 then Val.low
                 when Def.default_value is not null and Def.default_value <> ''
                 then Def.default_value
                 else 'UTC' end as tznzone )                as TimeZone
}
where
  Lang.Language = $session.system_language

// Artifact: zi_ca_opsctltz.ddls.asddls
// Purpose: Time zone of the business date of the daily control review: parameter CONTROL_TIME_ZONE of
//          area CA_OPS (ZCA_PARAM) - the maintained value (row 1), else the definition default, else UTC
//          (also when the definition is not transported). Exactly one row (the logon language row of
//          I_Language). CDS cannot call the parameter API, so the framework's parameter tables are read
//          directly with the API's resolution, read-only (the same rule as ZCL_CA_OPS_PARAMS).
// Modification log: 2026-11-10 | Initial version (control register and daily control review).
// VERIFY-ADT: left outer join with an ON condition of literals only (7.58); fallback: inner join and the
//             definition delivered with the framework (config/param_definitions.csv).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Control review: time zone (ZCA_PARAM)'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_CA_OpsCtlTz
  as select from    I_Language    as Lang
    left outer join zca_param_def as Def on  Def.area = 'CA_OPS'
                                         and Def.name = 'CONTROL_TIME_ZONE'
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

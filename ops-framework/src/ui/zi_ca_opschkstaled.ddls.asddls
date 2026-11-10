// Artifact: zi_ca_opschkstaled.ddls.asddls
// Purpose: Default freshness threshold of the area dashboard: parameter CHECK_STALE_MIN_DEFAULT of area CA_OPS
//          (ZCA_PARAM) - the maintained value (row 1), else the definition default, else 1500 minutes
//          (ZIF_CA_OPS_CHK_TYPES=>GC_PARAM_DEFAULT-STALE_DEFAULT, also when the definition is not transported).
//          Exactly one row (the logon language row of I_Language, as ZI_CA_OpsCtlTz). Read-only.
// Modification log: 2026-11-10 | Initial version (process onboarding: area dashboard and freshness).
// VERIFY-ADT: left outer join with an ON condition of literals only (7.58), as ZI_CA_OpsCtlTz.
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Area dashboard: default stale threshold'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_CA_OpsChkStaleD
  as select from    I_Language    as Lang
    left outer join zca_param_def as Def on  Def.area = 'CA_OPS'
                                         and Def.name = 'CHECK_STALE_MIN_DEFAULT'
    left outer join zca_param_val as Val on  Val.area = Def.area
                                         and Val.name = Def.name
                                         and Val.numb = 1
{
  key Lang.Language                                         as Language,
      cast( case when Val.low is not null and Val.low <> ''
                 then Val.low
                 when Def.default_value is not null and Def.default_value <> ''
                 then Def.default_value
                 else '1500' end as abap.int4 )             as StaleAfterMinutes
}
where
  Lang.Language = $session.system_language

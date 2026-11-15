// Artifact: zi_ca_opsliccfg.ddls.asddls
// Purpose: Licence dashboard - the one row of today: the active licence of ZCA_OPS_LIC (its key, ID and grace days)
//          and the warning days LIC_WARN_DAYS of area CA_OPS (ZCA_PARAM: the maintained value, else the definition
//          default, else 30 - ZIF_CA_OPS_LIC_TYPES=>GC_DEFAULT-WARN_DAYS). Exactly one row (the logon language row of
//          I_Language, as ZI_CA_OpsFlowCfg); no licence installed = the licence columns are null. Display only: the
//          runtime decides from the verified file (ZCL_CA_OPS_LICENSE). Read-only.
// Modification log: 2026-11-15 | Initial version (licensing).
// VERIFY-ADT (V165): left outer joins with ON conditions of literals only and the CHAR -> INT4 cast of a parameter
//          value (as ZI_CA_OpsChkStaleA).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Licence: active licence and warning days'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_CA_OpsLicCfg
  as select from    I_Language    as Lang
    left outer join zca_param_def as Def on  Def.area = 'CA_OPS'
                                         and Def.name = 'LIC_WARN_DAYS'
    left outer join zca_param_val as Val on  Val.area = Def.area
                                         and Val.name = Def.name
                                         and Val.numb = 1
    left outer join zca_ops_lic   as Lic on  Lic.active = 'X'
{
  key Lang.Language                                         as Language,
      // The framework validates the value type INT (0-365) on save, so the text is a number
      cast( case when Val.low is not null and Val.low <> ''
                 then Val.low
                 when Def.default_value is not null and Def.default_value <> ''
                 then Def.default_value
                 else '30' end as abap.int4 )               as WarnDays,
      Lic.lic_uuid                                          as LicenseUuid,
      Lic.license_id                                        as LicenseId,
      Lic.customer                                          as Customer,
      cast( coalesce( Lic.grace_days, 0 ) as abap.int4 )    as GraceDays
}
where
  Lang.Language = $session.system_language

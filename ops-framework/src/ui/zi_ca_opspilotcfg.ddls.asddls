// Artifact: zi_ca_opspilotcfg.ddls.asddls
// Purpose: Pilot pack: the reason code that marks a false positive - parameter PILOT_FP_REASON of area CA_OPS
//          (ZCA_PARAM): the maintained value (row 1), else the definition default, else NOT_AN_ISSUE. Exactly one row
//          (the logon language row of I_Language). CDS cannot call the parameter API, so the parameter tables are
//          read with the API's resolution, read-only (the rule of ZI_CA_OpsCtlTz).
// Modification log: 2026-11-11 | Initial version (build F: pilot pack).
// VERIFY-ADT: left outer join with an ON condition of literals only (7.58), as ZI_CA_OpsCtlTz.
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Pilot pack: false-positive reason'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_CA_OpsPilotCfg
  as select from    I_Language    as Lang
    left outer join zca_param_def as Def on  Def.area = 'CA_OPS'
                                         and Def.name = 'PILOT_FP_REASON'
    left outer join zca_param_val as Val on  Val.area = Def.area
                                         and Val.name = Def.name
                                         and Val.numb = 1
{
  key Lang.Language                                         as Language,
      cast( case when Val.low is not null and Val.low <> ''
                 then Val.low
                 when Def.default_value is not null and Def.default_value <> ''
                 then Def.default_value
                 else 'NOT_AN_ISSUE' end as abap.char( 12 ) ) as FalsePositiveReason
}
where
  Lang.Language = $session.system_language

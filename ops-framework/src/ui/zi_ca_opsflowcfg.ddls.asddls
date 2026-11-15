// Artifact: zi_ca_opsflowcfg.ddls.asddls
// Purpose: Account flow reconciliation - the ledger of the journal lines when a flow names none: parameter FLOW_LEDGER
//          of area CA_OPS (ZCA_PARAM) - the maintained value (row 1), else the definition default, else the leading
//          ledger 0L (ZIF_CA_OPS_FLOW_TYPES=>GC_DEFAULT-LEDGER, also when the definition is not transported). Exactly
//          one row (the logon language row of I_Language, as ZI_CA_OpsChkStaleD). Read-only.
// Modification log: 2026-11-15 | Initial version (build G: account flow reconciliation).
// VERIFY-ADT: left outer join with an ON condition of literals only (7.58), as ZI_CA_OpsChkStaleD (V147).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Account flow: ledger parameter'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_CA_OpsFlowCfg
  as select from    I_Language    as Lang
    left outer join zca_param_def as Def on  Def.area = 'CA_OPS'
                                         and Def.name = 'FLOW_LEDGER'
    left outer join zca_param_val as Val on  Val.area = Def.area
                                         and Val.name = Def.name
                                         and Val.numb = 1
{
  key Lang.Language                                         as Language,
      cast( case when Val.low is not null and Val.low <> ''
                 then Val.low
                 when Def.default_value is not null and Def.default_value <> ''
                 then Def.default_value
                 else '0L' end as abap.char( 2 ) )          as Ledger
}
where
  Lang.Language = $session.system_language

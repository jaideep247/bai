// Artifact: zi_cd_postareacfg.ddls.asddls
// Purpose: Posting-area settings of the payment model, one row: application area (POSTAREA_APPLK), posting area of
//          the payment method classes (POSTAREA_PMC) and chart of accounts (POSTAREA_KTOPL) - the ZCA_PARAM
//          parameters of area CD_OPS that ZCL_CD_OPS_POSTAREA_DAO reads through the API, here with the API's
//          resolution (maintained value row 1, else the definition default) because CDS cannot call the API
//          (the exception of ZI_CD_OpsStaleCfg). Parameter names compared with ZIF_CD_OPS_POSTAREA_TYPES
//          (portable check cds_abap_parity). Read-only.
// Modification log: 2026-11-11 | Initial version (payment model: method class of every payment, FS-CD mapping).
// VERIFY-ADT: CHAR results of CASE in MAX( ) of a grouped view (7.58).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment model - posting-area settings'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_CD_PostAreaCfg
  as select from    zca_param_def as Def
    left outer join zca_param_val as Val on  Val.area = Def.area
                                         and Val.name = Def.name
                                         and Val.numb = 1
{
  key Def.area                                              as ParamArea,
      max( case when Def.name = 'POSTAREA_APPLK'
                then case when Val.low is null or Val.low = '' then Def.default_value else Val.low end
                else '' end )                               as ApplicationArea,
      max( case when Def.name = 'POSTAREA_PMC'
                then case when Val.low is null or Val.low = '' then Def.default_value else Val.low end
                else '' end )                               as MethodClassArea,
      max( case when Def.name = 'POSTAREA_KTOPL'
                then case when Val.low is null or Val.low = '' then Def.default_value else Val.low end
                else '' end )                               as ChartOfAccounts
}
where
  Def.area = 'CD_OPS'
group by
  Def.area

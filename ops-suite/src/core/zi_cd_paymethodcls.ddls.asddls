// Artifact: zi_cd_paymethodcls.ddls.asddls
// Purpose: Payment method class of every payment method and flow from the FI-CA customer posting area ZPMC
//          (TFK033D, maintained by the FI-CA team in FQC0; FICA_Posting_Areas.md): KEY01 = flow D / C, KEY02 =
//          payment method, KEY03 = house bank '*' (the class row; house-bank rows only override the calendar),
//          FUN01 = method class (WIR, ACH, CHQ, CRD, ACI ...). The same entries ZCL_CD_OPS_POSTAREA reads for the
//          in-flight rules - one source, never hard-coded; posting area, application area and chart of accounts
//          from ZI_CD_PostAreaCfg. Source per purpose (2026-11-15): POSTAREA_SOURCE_PMC = T reads the active version
//          (POSTAREA_VERSION_PMC) of the typed table ZCD_OPS_MAPPMC instead, house bank '*' - the same rows
//          ZCL_CD_OPS_POSTAREA reads. Used by the payment model mapping (config/payment_model/mapping.json). Read-only.
// Modification log: 2026-11-11 | Initial version (payment model: payment method as a first-class category).
//                   2026-11-15 | Union with the typed table ZCD_OPS_MAPPMC by the source of the method classes.
// VERIFY-DDIC: TFK033D fields APPLK, BUBER, KTOPL, KEY01..KEY03, FUN01 (as ZCL_CD_OPS_POSTAREA_DAO).
// VERIFY-ADT: UNION ALL with key elements in a view entity; NUMC version compared with the padded CHAR parameter.
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment model - method class per method'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #A, sizeCategory: #S, dataClass: #CUSTOMIZING }
define view entity ZI_CD_PayMethodCls
  as select from ZI_CD_PostAreaCfg as Cfg
    inner join   tfk033d           as Ent on  Ent.applk = Cfg.ApplicationArea
                                          and Ent.buber = Cfg.MethodClassArea
                                          and Ent.ktopl = Cfg.ChartOfAccounts
{
  key cast( Ent.key01 as abap.char( 1 ) )                   as Flow,
  key cast( Ent.key02 as abap.char( 1 ) )                   as PaymentMethod,
      cast( Ent.fun01 as abap.char( 3 ) )                   as MethodClass
}
where
      Ent.key03             = '*'
  and Cfg.MethodClassSource = 'P'

union all

  select from ZI_CD_PostAreaCfg as Cfg
    inner join   zcd_ops_mappmc    as Map on Map.version = Cfg.MethodClassVersion
{
  key Map.flow                                              as Flow,
  key Map.pay_method                                        as PaymentMethod,
      Map.method_class                                      as MethodClass
}
where
      Map.house_bank        = '*'
  and Cfg.MethodClassSource = 'T'

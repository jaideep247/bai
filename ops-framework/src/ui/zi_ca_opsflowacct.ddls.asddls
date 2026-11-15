// Artifact: zi_ca_opsflowacct.ddls.asddls
// Purpose: Account flow reconciliation - the columns of the dashboard: every active account (ZCA_OPS_FLWACC) of an
//          active flow (ZCA_OPS_FLOW) with its role, company code, the G/L account range (last account = first when
//          none is given), the currency range (blank currency = every currency: '' to 'ZZZZZ'), the line source (G
//          journal, F FI-CA documents), the source class of what checks account for and its tile, and the ledger of
//          the journal lines (the flow's, else FLOW_LEDGER - ZI_CA_OpsFlowCfg); the texts of the company code and of
//          the (first) G/L account from SAP's released views I_CompanyCode and I_GLAccountText. Ranges instead of
//          patterns: a range is a join condition HANA evaluates on the journal's column store; a PCRE pattern would
//          need every line in ABAP. Read-only.
// Modification log: 2026-11-15 | Initial version (build G: account flow reconciliation).
// VERIFY-ADT: cross join with the one-row parameter view (as ZR_CA_OpsCheckStatus), CASE with a SAKNR / CHAR 5 cast;
//             I_CompanyCode ChartOfAccounts / CompanyCodeName and I_GLAccountText ChartOfAccounts / GLAccount /
//             Language / GLAccountLongName (V110 names; CompanyCodeName VERIFY-ADT) - V147.
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Account flow: accounts by role'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #A, sizeCategory: #S, dataClass: #CUSTOMIZING }
define view entity ZI_CA_OpsFlowAcct
  as select from    zca_ops_flwacc   as Acc
    inner join      zca_ops_flow     as Flw on  Flw.area    = Acc.area
                                            and Flw.flow_id = Acc.flow_id
    cross join      ZI_CA_OpsFlowCfg as Cfg
    left outer join I_CompanyCode    as Cc  on  Cc.CompanyCode = Acc.bukrs
    left outer join I_GLAccountText  as Txt on  Txt.ChartOfAccounts = Cc.ChartOfAccounts
                                            and Txt.GLAccount       = Acc.hkont_from
                                            and Txt.Language        = $session.system_language
{
  key Acc.area                                              as Area,
  key Acc.flow_id                                           as FlowId,
  key Acc.flow_acct                                         as FlowAccount,
      cast( Acc.role as zca_ops_flow_role )                 as AccountRole,
      Acc.bukrs                                             as CompanyCode,
      Acc.currency                                          as Currency,
      Acc.hkont_from                                        as GLAccountFrom,
      cast( case when Acc.hkont_to = '' then Acc.hkont_from
                 else Acc.hkont_to end as saknr )           as GLAccountTo,
      cast( Acc.currency as abap.char( 5 ) )                as CurrencyLow,
      cast( case when Acc.currency = '' then 'ZZZZZ'
                 else Acc.currency end as abap.char( 5 ) )  as CurrencyHigh,
      Acc.line_source                                       as LineSource,
      Acc.seq                                               as DisplaySeq,
      Acc.eval_class                                        as EvalClass,
      Acc.eval_category                                     as EvalCategory,
      Acc.description                                       as AccountName,
      Txt.GLAccountLongName                                 as GLAccountName,
      Cc.CompanyCodeName                                    as CompanyCodeName,
      Flw.description                                       as FlowName,
      Flw.direction                                         as Direction,
      cast( case when Flw.jrnl_ledger = '' then Cfg.Ledger
                 else Flw.jrnl_ledger end as abap.char( 2 ) ) as Ledger
}
where
      Acc.active = 'X'
  and Flw.active = 'X'

// Artifact: zi_ca_opsflowcube.ddls.asddls
// Purpose: Account flow reconciliation - analytical cube of the dashboard (embedded analytics: the multidimensional
//          report, Analysis for Office, the query ZC_CA_OpsFlowQry): rows of ZI_CA_OpsFlowFact for the posting date
//          window P_DateFrom - P_DateTo, with the stage (sequence and text; reserved rows after the stages: OTHER,
//          MOVEMENT, OPENING, CLOSING, UNEXPLAINED), the account column (role, account, its order and text, company
//          code), the stage's control tag per company code (ZI_CA_OpsFlowTag: R reconciled, O n open, P pending, N
//          none - reserved rows have none) and the account's evaluation status on the Unexplained row (E evaluated, N
//          not evaluated - grey, X no control point). Measures debit and credit (movement, positions, unexplained),
//          expected debit / credit (brackets), reached G/L debit / credit of a subledger-posted account, lines, accounts
//          not evaluated, open exceptions of the stage's checks. The currency is a dimension: amounts are summed per
//          currency only, never across. Read access: DCL ZI_CA_OPSFLOWCUBE (ZCA_OPS 03 for the area and the company
//          code).
// Modification log: 2026-11-15 | Initial version (build G: account flow reconciliation).
// VERIFY-ADT (V147): @Analytics.dataCategory #CUBE over a view entity with parameters and a UNION source (7.58),
//          #MAX aggregation of an INT4, text elements by language join, currency as a dimension of DEC measures (as
//          ZI_CA_OpsBrkCube, V136).
// Extension point FLOW (2026-11-15, build H; config/extension_points.json, docs/EXTENDING_WITH_CUSTOMER_DATA.md):
//          base view; a customer adds its own elements with extend view entity from its package,
//          never by changing this view. Anchors COMPANY, STAGE, ACCOUNT: their elements stay stable.
// VERIFY-ADT (V153): the extensibility annotations below on 7.58.
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Account flow - cube'
@Analytics.dataCategory: #CUBE
@VDM.viewType: #COMPOSITE
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #L, dataClass: #TRANSACTIONAL }
@AbapCatalog.extensibility.extensible: true
@AbapCatalog.extensibility.elementSuffix: 'ZOP'
@AbapCatalog.extensibility.allowNewDatasources: true
@AbapCatalog.extensibility.dataSources: [ 'Fct' ]
@AbapCatalog.extensibility.quota.maximumFields: 50
@AbapCatalog.extensibility.quota.maximumBytes: 2000
define view entity ZI_CA_OpsFlowCube
  with parameters
    P_DateFrom : abap.dats,
    P_DateTo   : abap.dats
  as select from    ZI_CA_OpsFlowFact( P_DateFrom : $parameters.P_DateFrom,
                                       P_DateTo   : $parameters.P_DateTo ) as Fct
    inner join      ZI_CA_OpsFlowAcct                                      as Acc  on  Acc.Area        = Fct.Area
                                                                                   and Acc.FlowId      = Fct.FlowId
                                                                                   and Acc.FlowAccount = Fct.FlowAccount
    left outer join zca_ops_flwstg                                         as Stg  on  Stg.area     = Fct.Area
                                                                                   and Stg.flow_id  = Fct.FlowId
                                                                                   and Stg.stage_id = Fct.StageId
    left outer join ZI_CA_OpsFlowRowT                                      as RowT on  RowT.StageId  = Fct.StageId
                                                                                   and RowT.Language = $session.system_language
    left outer join ZI_CA_OpsFlowRoleT                                     as RolT on  RolT.AccountRole = Acc.AccountRole
                                                                                   and RolT.Language    = $session.system_language
    left outer join ZI_CA_OpsFlowTag                                       as Tag  on  Tag.Area        = Fct.Area
                                                                                   and Tag.FlowId      = Fct.FlowId
                                                                                   and Tag.StageId     = Fct.StageId
                                                                                   and Tag.CompanyCode = Acc.CompanyCode
{
  key Fct.Area                                              as Area,
  @ObjectModel.text.element: [ 'FlowName' ]
  key Fct.FlowId                                            as FlowId,
  @ObjectModel.text.element: [ 'AccountName' ]
  key Fct.FlowAccount                                       as FlowAccount,
  key Fct.Currency                                          as Currency,
  @ObjectModel.text.element: [ 'StageName' ]
  key Fct.StageId                                           as StageId,
  key Fct.RowKind                                           as RowKind,
  key Fct.LineSource                                        as LineSource,
  key Fct.ReferenceType                                     as ReferenceType,
  key Fct.DocumentType                                      as DocumentType,
  key Fct.Origin                                            as Origin,
  key Fct.MainTransaction                                   as MainTransaction,
  key Fct.SubTransaction                                    as SubTransaction,
  key Fct.DebitCredit                                       as DebitCredit,
      Acc.FlowName                                          as FlowName,
      Acc.AccountName                                       as AccountName,
      @ObjectModel.text.element: [ 'CompanyCodeName' ]
      Acc.CompanyCode                                       as CompanyCode,
      Acc.CompanyCodeName                                   as CompanyCodeName,
      Acc.GLAccountFrom                                     as GLAccount,
      Acc.GLAccountName                                     as GLAccountName,
      @ObjectModel.text.element: [ 'AccountRoleName' ]
      Acc.AccountRole                                       as AccountRole,
      RolT.AccountRoleText                                  as AccountRoleName,
      Acc.DisplaySeq                                        as AccountOrder,
      cast( case Fct.StageId when 'OTHER'       then 9000
                             when 'MOVEMENT'    then 9100
                             when 'OPENING'     then 9200
                             when 'CLOSING'     then 9300
                             when 'UNEXPLAINED' then 9400
                             else coalesce( Stg.seq, 8999 ) end as abap.int4 ) as StageOrder,
      cast( coalesce( Stg.description, RowT.StageIdText ) as abap.char( 60 ) ) as StageName,
      Fct.RuleId                                            as RuleId,
      cast( case
              when Fct.RowKind <> 'S' and Fct.RowKind <> 'Z' and Fct.RowKind <> 'E' then ' '
              when Fct.StageId = 'OTHER' then 'N'
              when Tag.CheckCount is null then 'N'
              when Tag.OpenExceptions > 0 then 'O'
              when Tag.PendingChecks > 0 then 'P'
              else 'R' end as zca_ops_flow_tag )            as ControlStatus,
      Fct.EvalStatus                                        as EvalStatus,
      @Aggregation.default: #SUM
      Fct.DebitAmount                                       as DebitAmount,
      @Aggregation.default: #SUM
      Fct.CreditAmount                                      as CreditAmount,
      @Aggregation.default: #SUM
      Fct.ExpectedDebit                                     as ExpectedDebit,
      @Aggregation.default: #SUM
      Fct.ExpectedCredit                                    as ExpectedCredit,
      @Aggregation.default: #SUM
      Fct.MemoDebit                                         as ReachedGlDebit,
      @Aggregation.default: #SUM
      Fct.MemoCredit                                        as ReachedGlCredit,
      @Aggregation.default: #SUM
      Fct.LineCount                                         as LineCount,
      @Aggregation.default: #SUM
      Fct.NotEvaluatedCount                                 as NotEvaluatedCount,
      @Aggregation.default: #MAX
      cast( case
              when Fct.RowKind <> 'S' and Fct.RowKind <> 'Z' and Fct.RowKind <> 'E' then 0
              else coalesce( Tag.OpenExceptions, 0 ) end as abap.int4 ) as ControlOpenCount
}

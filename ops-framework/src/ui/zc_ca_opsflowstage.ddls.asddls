// Artifact: zc_ca_opsflowstage.ddls.asddls
// Purpose: Account flow reconciliation - the stages of every active flow per company code of its accounts with their
//          control tag (ZI_CA_OpsFlowStgTag; overview page list card of service ZUI_CA_OPS_FLOW): R reconciled, O
//          open (the number of open exceptions of its checks), P pending (a check without a current result), N no
//          control (no check configured - the stage is shown, never as reconciled; grey). Derived now, nothing
//          stored; no posting date window (a control tag is the latest result). Read access: DCL ZC_CA_OPSFLOWSTAGE
//          (area, company code).
// Modification log: 2026-11-15 | Initial version (build G: account flow reconciliation).
// VERIFY-ADT (V147): language join to a domain text view.
// Extension point FLOW_STAGE (2026-11-15, build H; config/extension_points.json, docs/EXTENDING_WITH_CUSTOMER_DATA.md):
//          base view; a customer adds its own elements with extend view entity from its package,
//          never by changing this view. Anchors COMPANY, STAGE: their elements stay stable.
// VERIFY-ADT (V153): the extensibility annotations below on 7.58.
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Account flow stages and controls'
@Metadata.allowExtensions: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #S, dataClass: #MIXED }
@AbapCatalog.extensibility.extensible: true
@AbapCatalog.extensibility.elementSuffix: 'ZOP'
@AbapCatalog.extensibility.allowNewDatasources: true
@AbapCatalog.extensibility.dataSources: [ 'Stg' ]
@AbapCatalog.extensibility.quota.maximumFields: 50
@AbapCatalog.extensibility.quota.maximumBytes: 2000
define view entity ZC_CA_OpsFlowStage
  as select from    ZI_CA_OpsFlowStgTag as Stg
    left outer join ZI_CA_OpsFlowTagT   as TagT on  TagT.ControlStatus = Stg.ControlStatus
                                                and TagT.Language      = $session.system_language
{
  key Stg.Area                                              as Area,
      @ObjectModel.text.element: [ 'FlowName' ]
  key Stg.FlowId                                            as FlowId,
      @ObjectModel.text.element: [ 'StageName' ]
  key Stg.StageId                                           as StageId,
  key Stg.CompanyCode                                       as CompanyCode,
      Stg.FlowName                                          as FlowName,
      Stg.StageName                                         as StageName,
      Stg.StageOrder                                        as StageOrder,
      @ObjectModel.text.element: [ 'ControlStatusText' ]
      Stg.ControlStatus                                     as ControlStatus,
      TagT.ControlStatusText                                as ControlStatusText,
      Stg.OpenExceptions                                    as OpenExceptions,
      Stg.CheckCount                                        as CheckCount,
      cast( case Stg.ControlStatus when 'O' then 1
                                   when 'R' then 3
                                   else 0 end as abap.int1 ) as ControlCriticality
}

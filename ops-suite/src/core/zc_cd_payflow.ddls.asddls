// Artifact: zc_cd_payflow.ddls.asddls
// Purpose: Consumption view of the process flow (overview page, entity PaymentFlow): per business date, company code
//          and stage - payments in the stage, stuck, reached, drop from the previous stage, criticality. Card now:
//          criticality list / bar card of Fiori elements; a flow diagram needs the custom card of
//          ui/cards/processflow (spec docs/Process_Flow_Card.md). Read access: DCL ZC_CD_OPSOVERVIEW (area CD_OPS and
//          the company code of the rows, as the payment lifecycle). Read-only.
// Modification log: 2026-11-11 | Initial version (process flow card of the overview page).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Production support - process flow'
@Metadata.allowExtensions: true
define root view entity ZC_CD_PayFlow
  provider contract transactional_query
  as projection on ZR_CD_PayFlow
{
  key BusinessDate,
  key CompanyCode,
      @ObjectModel.text.element: [ 'StageLabel' ]
  key Stage,
      StageSequence,
      @Semantics.text: true
      StageLabel,
      StageSource,
      PaymentEngineArea,
      IsCurrentDay,
      StuckAfterDays,
      AgeDays,
      @Aggregation.default: #SUM
      PaymentCount,
      @Aggregation.default: #SUM
      StuckCount,
      @Aggregation.default: #SUM
      ReachedCount,
      @Aggregation.default: #SUM
      DropCount,
      FlowCriticality
}

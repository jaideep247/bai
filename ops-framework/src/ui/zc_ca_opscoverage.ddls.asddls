// Artifact: zc_ca_opscoverage.ddls.asddls
// Purpose: Consumption view of the monitor coverage (service ZUI_CA_OPS_DASH, list "Monitor coverage" and a
//          consumer's overview card per area and licence module: expected, ran, impaired, not run, disabled,
//          refused, warned - a monitor gap is shown, never silence; annotations in the metadata extension). Read
//          access: DCL ZC_CA_OPSCOVERAGE (ZCA_OPS 03 for the area). Read-only.
// Modification log: 2026-11-16 | Initial version (build O: monitor coverage state).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Monitor coverage per check'
@Metadata.allowExtensions: true
@Search.searchable: true
define root view entity ZC_CA_OpsCoverage
  provider contract transactional_query
  as projection on ZR_CA_OpsCoverage
{
      @Search.defaultSearchElement: true
  key Area,
      @Search.defaultSearchElement: true
  key CheckId,
      @Search.defaultSearchElement: true
      CheckName,
      ProcessId,
      CatalogueProcess,
      ClassName,
      ScheduleGroup,
      LicenceModule,
      @ObjectModel.text.element: [ 'CoverageStateText' ]
      CoverageState,
      _CoverageText.CoverageStateText                       as CoverageStateText : localized,
      CoverageCriticality,
      IsExpected,
      @ObjectModel.text.element: [ 'EvaluationStateText' ]
      EvaluationState,
      _EvalText.EvaluationStateText                         as EvaluationStateText : localized,
      EvaluationCriticality,
      EvaluatedAt,
      WindowMinutes,
      EvaluationReason,
      LicenceState,
      @Aggregation.default: #SUM
      CheckCount,
      @Aggregation.default: #SUM
      ExpectedCount,
      @Aggregation.default: #SUM
      RanCount,
      @Aggregation.default: #SUM
      ImpairedCount,
      @Aggregation.default: #SUM
      NotRunCount,
      @Aggregation.default: #SUM
      DisabledCount,
      @Aggregation.default: #SUM
      RefusedCount,
      @Aggregation.default: #SUM
      WarnedCount,
      @Aggregation.default: #SUM
      GapCount
}

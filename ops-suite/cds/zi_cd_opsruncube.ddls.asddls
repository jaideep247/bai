// Artifact: zi_cd_opsruncube.ddls.asddls
// Purpose: Analytical cube of suite runs: runs, runtime, items and findings per
//          payment engine area / day / RAG. Release-dependent annotations: verify on target release.
// Modification log: 2026-11-05 | Initial version (ops suite consolidation).
//                   2026-11-10 | Company-code isolation: FindingCount removed (see ZI_CD_OpsRun).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Ops suite runs - cube'
@Metadata.ignorePropagatedAnnotations: true
@Analytics.dataCategory: #CUBE
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #M, dataClass: #MIXED }
@VDM.viewType: #COMPOSITE
define view entity ZI_CD_OpsRunCube
  as select from ZI_CD_OpsRun
{
  key RunId,
      PaymentEngineArea,
      Variant,
      RunDate,
      RunStatus,
      Rag,
      CreatedBy,
      @Aggregation.default: #SUM
      cast( 1 as abap.int4 )                              as RunCount,
      @Aggregation.default: #SUM
      cast( case Rag when 'R' then 1 else 0 end as abap.int4 ) as RedRunCount,
      @Aggregation.default: #SUM
      RuntimeMs,
      @Aggregation.default: #MAX
      cast( RuntimeMs as abap.int4 )                      as MaxRuntimeMs,
      @Aggregation.default: #SUM
      TotalItems,
      @Aggregation.default: #SUM
      FailedItems,
      @Aggregation.default: #SUM
      WarningItems
}
where IsTestMode = ''

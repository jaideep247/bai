// Artifact: zi_cd_fmonflowcube.ddls.asddls
// Purpose: Analytical cube of the file monitoring dashboard for Analysis for Office / query
//          browser (the Fiori deliverable is the analytical list page ZUI_CD_FMON_FLOW):
//          files, records, control totals, ACK / NACK, unprocessed items and flow-bucket counts
//          per source / LOB / payment method / bank / interface / direction / business date.
//          No SLA status or monitor as-of here - use the list page for those.
//          Release-dependent annotations: verify on target release.
// Modification log: 2026-11-06 | Initial version (FMON file monitoring dashboard).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'FMON file monitoring - cube'
@Metadata.ignorePropagatedAnnotations: true
@Analytics.dataCategory: #CUBE
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #L, dataClass: #MIXED }
@VDM.viewType: #COMPOSITE
define view entity ZI_CD_FmonFlowCube
  as select from ZI_CD_FmonFlowFile
{
  key FileId,
      PaymentEngineArea,
      IfaceId,
      Direction,
      FileType,
      SourceSystem,
      Lob,
      PaymentMethod,
      BankKey,
      BusinessDate,
      FlowBucket,
      IsSuccess,
      @Aggregation.default: #SUM
      FileCount,
      @Aggregation.default: #SUM
      SuccessFileCount,
      @Aggregation.default: #SUM
      cast( case FlowBucket when 'REJECTED' then 1 else 0 end as abap.int4 ) as RejectedFileCount,
      @Aggregation.default: #SUM
      cast( case FlowBucket when 'PARTIAL' then 1 else 0 end as abap.int4 )  as PartialFileCount,
      @Aggregation.default: #SUM
      cast( case FlowBucket when 'ACKNOWLEDGED' then 1 else 0 end as abap.int4 ) as AckFileCount,
      @Aggregation.default: #SUM
      RecordCount,
      // No currency on the file row: slice by interface before reading totals
      @Aggregation.default: #SUM
      ControlTotal,
      @Aggregation.default: #SUM
      AckCount,
      @Aggregation.default: #SUM
      AckAmount,
      @Aggregation.default: #SUM
      NackCount,
      @Aggregation.default: #SUM
      UnprocessedCount
}

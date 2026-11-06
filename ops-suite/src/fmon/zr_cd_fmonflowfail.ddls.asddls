// Artifact: zr_cd_fmonflowfail.ddls.asddls
// Purpose: "Latest failures" list of the file monitoring dashboard (launchpad list card and the
//          production-support overview page list card): files that were rejected or failed
//          (bucket REJECTED, incl. PRISM_FAILED), partially processed (PARTIAL) or whose SLA is
//          breached - newest last event first (presentation variant), the card shows the top n.
//          Read-only.
// Modification log: 2026-11-06 | Initial version (FMON file monitoring dashboard).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'FMON file monitoring dashboard - failures'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #M, dataClass: #MIXED }
define root view entity ZR_CD_FmonFlowFail
  as select from ZR_CD_FmonFlow
{
  key FileId,
      PaymentEngineArea,
      BusinessDate,
      IsToday,
      IfaceId,
      Direction,
      SourceSystem,
      Lob,
      PaymentMethod,
      BankKey,
      FileName,
      FlowBucket,
      FlowCriticality,
      SlaStatus,
      SlaCriticality,
      WorstSeverity,
      LastEventAt,
      RecordCount,
      UnprocessedCount,
      NackCount,
      OpenFindingCount
}
where FlowBucket = 'REJECTED'
   or FlowBucket = 'PARTIAL'
   or SlaStatus  = 'BREACHED'

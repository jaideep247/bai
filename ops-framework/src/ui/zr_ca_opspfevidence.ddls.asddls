// Artifact: zr_ca_opspfevidence.ddls.asddls
// Purpose: Payment file lifecycle - the evidence of a file at source grain (ZCA_OPS_PFEVT): which SAP, middleware or
//          bank record evidenced which milestone and outcome, its native status, source, logical system and client,
//          its own record ID and version, when it happened and when it was observed, business date, amount with its
//          currency, scope (file, batch, payment), correlation quality, repeated reference, and the link registry
//          object and key values a link walker can start from. The company code is the file's (DCL). Read-only.
// Modification log: 2026-11-15 | Initial version (build K: payment file lifecycle).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment file evidence'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define root view entity ZR_CA_OpsPfEvidence
  as select from zca_ops_pfevt  as Evt
    inner join   zca_ops_pffile as Fil on  Fil.area    = Evt.area
                                       and Fil.file_id = Evt.file_id
{
  key Evt.area                                              as Area,
  key Evt.event_key                                         as EventKey,
      Evt.file_id                                           as FileId,
      Fil.bukrs                                             as CompanyCode,
      Evt.milestone                                         as Milestone,
      Evt.outcome                                           as Outcome,
      Evt.native_status                                     as NativeStatus,
      Evt.source_id                                         as SourceId,
      Evt.source_type                                       as SourceType,
      Evt.logsys                                            as LogicalSystem,
      Evt.sys_client                                        as SourceClient,
      Evt.native_key                                        as NativeKey,
      Evt.source_event_id                                   as SourceRecordId,
      Evt.event_version                                     as RecordVersion,
      Evt.occurred_at                                       as OccurredAt,
      Evt.observed_at                                       as ObservedAt,
      Evt.bus_date                                          as BusinessDate,
      Evt.amount                                            as Amount,
      Evt.currency                                          as Currency,
      Evt.item_count                                        as ItemCount,
      Evt.ack_scope                                         as AckScope,
      Evt.batch_id                                          as BatchId,
      Evt.pay_key                                           as PaymentKey,
      Evt.corr_quality                                      as CorrelationQuality,
      Evt.repeat_no                                         as RepeatedReference,
      Evt.link_object                                       as LinkObject,
      Evt.link_value                                        as LinkValues,
      Evt.info                                              as Info
}

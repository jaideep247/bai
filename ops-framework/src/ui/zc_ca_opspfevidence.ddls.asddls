// Artifact: zc_ca_opspfevidence.ddls.asddls
// Purpose: Payment file lifecycle - consumption view of the evidence rows of a file at source grain (object page facet of ZC_CA_OpsPayFile). Read access: DCL ZC_CA_OPSPFEVIDENCE.
// Modification log: 2026-11-15 | Initial version (build K: payment file lifecycle).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Payment file evidence'
@Metadata.allowExtensions: true
define root view entity ZC_CA_OpsPfEvidence
  provider contract transactional_query
  as projection on ZR_CA_OpsPfEvidence
{
  key Area,
  key EventKey,
      FileId,
      CompanyCode,
      Milestone,
      Outcome,
      NativeStatus,
      SourceId,
      SourceType,
      LogicalSystem,
      SourceClient,
      NativeKey,
      SourceRecordId,
      RecordVersion,
      OccurredAt,
      ObservedAt,
      BusinessDate,
      Amount,
      Currency,
      ItemCount,
      AckScope,
      BatchId,
      PaymentKey,
      CorrelationQuality,
      RepeatedReference,
      LinkObject,
      LinkValues,
      Info
}

// Artifact: zc_ca_opsfindevidence.ddls.asddls
// Purpose: Exception contract (docs/EXCEPTION_CONTRACT.md) - the typed evidence rows of an exception (ZCA_OPS_FNDEVI):
//          the system that holds the record (SAP, MW, BANK, OPS), its type (run, job, payment document, file, message,
//          acknowledgement, statement line), label, own key, the link registry object and key values a link walk
//          starts from, when it happened and was observed, and the match quality. Facet "Evidence" of the exceptions
//          app (association _Evidence of ZR_CA_OpsException) for every module that adopts the contract. Read access:
//          DCL ZC_CA_OPSFINDEVIDENCE (area and the finding's company code). Read-only.
// Modification log: 2026-11-15 | Initial version (build K: exception contract).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Evidence of an exception'
@Metadata.allowExtensions: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define view entity ZC_CA_OpsFindEvidence
  as select from zca_ops_fndevi       as Evi
    inner join   ZI_CA_OpsFindEvidKey as Key on  Key.Area        = Evi.area
                                             and Key.EvidenceKey = Evi.evid_key
{
  key Evi.area                                              as Area,
  key Evi.evid_key                                          as EvidenceKey,
  key Evi.seq                                               as Sequence,
      Key.CompanyCode                                       as CompanyCode,
      Evi.kind                                              as SystemKind,
      Evi.ev_type                                           as EvidenceType,
      Evi.label                                             as Label,
      Evi.native_key                                        as NativeKey,
      Evi.link_object                                       as LinkObject,
      Evi.link_value                                        as LinkValues,
      Evi.occurred_at                                       as OccurredAt,
      Evi.observed_at                                       as ObservedAt,
      Evi.quality                                           as Quality,
      Evi.source_id                                         as SourceId
}

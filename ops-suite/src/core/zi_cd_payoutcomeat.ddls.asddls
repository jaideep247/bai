// Artifact: zi_cd_payoutcomeat.ddls.asddls
// Purpose: The canonical payment outcome valid at the "as of" instant (valid_from <= as of <
//          valid_to): one row per FIN + source + company code + payment document (the snapshot
//          closes the version of an older payment run when a newer one is judged, so one run per
//          key is valid at any instant). Default now = the current version. History exists from
//          go-live only: before it no row is valid. The request side (cds/ZR_CD_TrxReqFlow) joins
//          it by FIN + source + company code + payment document. Read-only.
// Modification log: 2026-11-07 | Initial version (one canonical payment outcome model, "as of").
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment outcome valid at an instant'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
@VDM.viewType: #COMPOSITE
define view entity ZI_CD_PayOutcomeAt
  with parameters
    P_AsOfDate : abap.dats,
    P_AsOfTime : abap.tims
  as select from ZI_CD_PayOutcomeTs( P_AsOfDate : $parameters.P_AsOfDate,
                                     P_AsOfTime : $parameters.P_AsOfTime ) as Version
{
  key Version.FinId,
  key Version.SourceSystem,
  key Version.CompanyCode,
  key Version.ClearingDoc,
      Version.RunDate,
      Version.RunId,
      Version.ValidFrom,
      Version.ValidTo,
      Version.Outcome,
      Version.EvidenceKind,
      Version.EvidenceRef,
      Version.Finding,
      Version.EvaluatedAt
}
where Version.ValidFrom <= Version.AsOfTimestamp
  and Version.ValidTo   >  Version.AsOfTimestamp

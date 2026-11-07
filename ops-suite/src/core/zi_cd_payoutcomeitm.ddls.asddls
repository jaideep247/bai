// Artifact: zi_cd_payoutcomeitm.ddls.asddls
// Purpose: The canonical payment outcome of a payment document for the SAP side of the
//          transactions dashboard (items carry the FIN, not the source): one row per FIN + company
//          code + payment document valid at the "as of" instant. Every value comes from one version
//          row: the rows of the sources of one FIN are grouped by every value they carry (the
//          snapshot writes them in one evaluation - a FIN in two sources is AMBIGUOUS in each), so
//          rows that differed would stay separate rows, never mixed by an independent MAX. The
//          number of sources is counted. Read-only.
// Modification log: 2026-11-07 | Initial version (one canonical payment outcome model).
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment outcome per FIN and payment'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
@VDM.viewType: #COMPOSITE
define view entity ZI_CD_PayOutcomeItm
  with parameters
    P_AsOfDate : abap.dats,
    P_AsOfTime : abap.tims
  as select from ZI_CD_PayOutcomeAt( P_AsOfDate : $parameters.P_AsOfDate,
                                     P_AsOfTime : $parameters.P_AsOfTime ) as Version
{
  key Version.FinId,
  key Version.CompanyCode,
  key Version.ClearingDoc,
      Version.RunDate,
      Version.RunId,
      Version.ValidFrom,
      Version.Outcome,
      Version.EvidenceKind,
      Version.EvidenceRef,
      Version.Finding,
      cast( count( * ) as abap.int4 )                       as SourceCount
}
group by
  Version.FinId,
  Version.CompanyCode,
  Version.ClearingDoc,
  Version.RunDate,
  Version.RunId,
  Version.ValidFrom,
  Version.Outcome,
  Version.EvidenceKind,
  Version.EvidenceRef,
  Version.Finding

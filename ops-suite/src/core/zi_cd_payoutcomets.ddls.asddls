// Artifact: zi_cd_payoutcomets.ddls.asddls
// Purpose: Payment outcome versions with the "as of" instant of the caller as a UTC time stamp
//          (date + time in the system time zone, default now): the comparison operand of
//          ZI_CD_PayOutcomeAt (valid_from <= as of < valid_to). No filter here. Read-only.
// Modification log: 2026-11-07 | Initial version (one canonical payment outcome model, "as of").
// VERIFY-ADT: dats_tims_to_tstmp with abap_system_timezone in a view entity element (7.58).
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment outcome version with as-of instant'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
@VDM.viewType: #COMPOSITE
define view entity ZI_CD_PayOutcomeTs
  with parameters
    P_AsOfDate : abap.dats,
    P_AsOfTime : abap.tims
  as select from ZI_CD_PayOutcome
{
  key FinId,
  key SourceSystem,
  key CompanyCode,
  key ClearingDoc,
  key RunDate,
  key RunId,
  key ValidFrom,
      ValidTo,
      Outcome,
      EvidenceKind,
      EvidenceRef,
      Finding,
      EvaluatedAt,
      dats_tims_to_tstmp( $parameters.P_AsOfDate, $parameters.P_AsOfTime,
                          abap_system_timezone( $session.client, 'NULL' ), $session.client, 'NULL' ) as AsOfTimestamp
}

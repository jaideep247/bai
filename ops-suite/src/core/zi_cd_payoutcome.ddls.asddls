// Artifact: zi_cd_payoutcome.ddls.asddls
// Purpose: Basic view of the canonical payment outcome history ZCD_PAY_OUTCOME (written only by the
//          5-minute snapshot ZCL_CD_OPS_PAY_SNAPSHOT from the evaluator ZIF_CD_OPS_PAY_OUTCOME): one row per
//          version of FIN + source + company code + payment document + payment run, valid from / to (UTC; open end
//          99991231235959 = current), outcome, deciding evidence kind and reference, finding. Keys
//          only: amounts, dates, partner and method are joined from DPAYH / DFKKOP / FEBEP /
//          ZCD_PAYM_REQ_LOG by the consumers. History exists from go-live only. Read-only.
// Modification log: 2026-11-07 | Initial version (one canonical payment outcome model).
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment outcome version (basic)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #A, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
@VDM.viewType: #BASIC
define view entity ZI_CD_PayOutcome
  as select from zcd_pay_outcome
{
  key fin_id                                                as FinId,
  key source                                                as SourceSystem,
  key bukrs                                                 as CompanyCode,
  key augbl                                                 as ClearingDoc,
  key laufd                                                 as RunDate,
  key laufi                                                 as RunId,
  key valid_from                                            as ValidFrom,
      valid_to                                              as ValidTo,
      outcome                                               as Outcome,
      evidence_kind                                         as EvidenceKind,
      evidence_ref                                          as EvidenceRef,
      finding                                               as Finding,
      evaluated_at                                          as EvaluatedAt
}

// Artifact: zi_cd_payworkstate.ddls.asddls
// Purpose: State of a payment document in the payment worklist (current rows of ZCD_PAY_OUTCOME by AUGBL, index
//          DOC) for the payment model: request source (MAX when the document paid requests of several sources),
//          open outcome (IN_FLIGHT, UNDETERMINED, INCONSISTENT ...), open finding (e.g. CHEQUE_REGISTER_MISSING,
//          PAY_STATUS_LAG) and late = finding PAYMENT_NOT_CLEARED - the in-flight rules of A_INFLIGHT (business
//          days per method class, posting area ZPMC; config/hck_seed.md section 8) decide it, nothing is restated
//          here. A clean final payment has no worklist row: no source here (source unknown bucket, see
//          Performance_Review.md section 12), not late, no outcome. Read-only.
// Modification log: 2026-11-11 | Initial version (payment model, FS-CD mapping).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment model - worklist state of a payment'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define view entity ZI_CD_PayWorkState
  as select from ZI_CD_PayOutcome as Work
{
  key Work.ClearingDoc,
      max( Work.SourceSystem )                              as SourceSystem,
      max( Work.Outcome )                                   as Outcome,
      max( Work.Finding )                                   as Finding,
      max( case Work.Finding when 'PAYMENT_NOT_CLEARED' then 'X' else ' ' end ) as IsLate
}
where
      Work.ValidTo     =  99991231235959
  and Work.ClearingDoc <> ' '
group by
  Work.ClearingDoc

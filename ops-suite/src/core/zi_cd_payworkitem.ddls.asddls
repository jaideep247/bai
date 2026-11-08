// Artifact: zi_cd_payworkitem.ddls.asddls
// Purpose: The current rows of the payment worklist (ZI_CD_PayOutcome, VALID_TO open) with what the
//          transactions dashboard shows next to them: kind PAYMENT (payment document filled) or REQUEST
//          (FIN + source of a payment request), open or exception (a finding), the payment run row of a
//          payment (DPAYH by its key LAUFD + LAUFI + DOC1R, proposal runs excluded: method, house bank,
//          value date, amount, currency, live status) and the direction (TFK042Z-XEINZ of the company
//          code's country). The worklist date is the run date of a payment and the due date of a request.
//          One row per worklist row; nothing is re-derived from evidence here (the outcome is the
//          snapshot's). Read-only.
// Modification log: 2026-11-08 | Initial version (exceptions-only worklist replaces the 400-day item driver
//                   and the "outcome as of" history of the transactions dashboard).
// VERIFY-SE11: DPAYH key LAUFD + LAUFI + DOC1R unique without proposal runs (as ZCL_CD_OPS_PAY_OUTCOME_DAO).
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment worklist - current row with payment'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #L, dataClass: #TRANSACTIONAL }
@VDM.viewType: #COMPOSITE
define view entity ZI_CD_PayWorkItem
  as select from    ZI_CD_PayOutcome as Work
    left outer join dpayh            as Pay on  Pay.laufd = Work.RunDate
                                            and Pay.laufi = Work.RunId
                                            and Pay.doc1r = Work.ClearingDoc
                                            and Pay.xvorl = ' '
    left outer join t001             as Cc  on  Cc.bukrs = Work.CompanyCode
    left outer join tfk042z          as Pm  on  Pm.land1 = Cc.land1
                                            and Pm.zlsch = Pay.pymet
{
  key Work.FinId,
  key Work.SourceSystem,
  key Work.CompanyCode,
  key Work.ClearingDoc,
  key Work.RunDate,
  key Work.RunId,
      cast( 'CORE' as abap.char( 4 ) )                      as PaymentEngineArea,
      cast( case when Work.ClearingDoc = ' ' then 'REQUEST'
                 else 'PAYMENT' end as abap.char( 7 ) )     as WorkKind,
      cast( case when Work.Finding <> ' ' then 'X'
                 else ' ' end as abap_boolean )             as IsException,
      Work.ValidFrom,
      Work.Outcome,
      Work.Finding,
      Work.Severity,
      Work.EvidenceKind,
      Work.EvidenceRef,
      Work.FlowClass,
      Work.DueDate,
      // The date of the row: run date of a payment, due date of a request
      cast( case when Work.ClearingDoc = ' ' then Work.DueDate
                 else Work.RunDate end as abap.dats )       as WorklistDate,
      case when Work.ClearingDoc = ' ' and Work.DueDate = $session.system_date then cast( 'X' as abap_boolean )
           when Work.ClearingDoc <> ' ' and Work.RunDate = $session.system_date then cast( 'X' as abap_boolean )
           else cast( ' ' as abap_boolean ) end             as IsToday,
      Pay.pymet                                             as PaymentMethod,
      Pay.hbkid                                             as HouseBank,
      // VERIFY-SE11: DPAYH-VALUT (as ZCL_CD_HCK_RUNTIME_DAO)
      Pay.valut                                             as ValueDate,
      Pay.zz_payment_status                                 as PaymentStatus,
      Pay.waers                                             as Currency,
      @Semantics.amount.currencyCode: 'Currency'
      abs( Pay.rwbtr )                                      as Amount,
      cast( case
              when Work.ClearingDoc = ' ' then 'DISBURSEMENT'
              when Pm.xeinz = 'X'         then 'COLLECTION'
              when Pm.zlsch is null       then 'UNKNOWN'
              else 'DISBURSEMENT' end as abap.char( 12 ) )  as Direction
}
where Work.ValidTo = 99991231235959

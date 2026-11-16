// Artifact: zr_ca_opspfpayment.ddls.asddls
// Purpose: Payment file lifecycle - the payments of a file (ZCA_OPS_PFPAY): key, company code, amount with its
//          currency (known or not), payee masked (the full number is never stored), payment document, method, batch,
//          the bank's payment-level answer and another file that carries the same payment (reissue: possible
//          duplicate). Affected payments facet of the worklist (paged by the UI). Read-only.
// Modification log: 2026-11-15 | Initial version (build K: payment file lifecycle).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payments of a payment file'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define root view entity ZR_CA_OpsPfPayment
  as select from zca_ops_pfpay as Pay
{
  key Pay.area                                              as Area,
  key Pay.file_id                                           as FileId,
  key Pay.pay_key                                           as PaymentKey,
      Pay.bukrs                                             as CompanyCode,
      Pay.currency                                          as Currency,
      Pay.amount                                            as Amount,
      Pay.amount_known                                      as AmountKnown,
      Pay.partner_masked                                    as PayeeMasked,
      Pay.pay_doc                                           as PaymentDocument,
      Pay.pay_method                                        as PaymentMethod,
      Pay.batch_id                                          as BatchId,
      Pay.ack_outcome                                       as AckOutcome,
      Pay.ack_at                                            as AckAt,
      Pay.other_file                                        as OtherFileId,
      cast( case when Pay.other_file is initial then ' ' else 'X' end as abap_boolean ) as PossibleDuplicate
}

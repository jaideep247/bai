// Artifact: zi_cd_paymreqfact.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Payment model of the ops suite - ADAPTER of the payment request: the contract fields of the product
//          (docs/ADDING_A_CUSTOMER_PAYMENT_MODEL.md) mapped to this landscape by the mapping spec config/payment_model/mapping.json.
//          The accepted attempt of a request = its row with ZZ_STATUS SUCCESS (confirmed rule: never the highest COUNTER,
//          a failed attempt can be written after the success).
// Modification log: 2026-11-11 | Generated from the mapping spec (payment model).
// PENDING (not imported): V82: FIN-number, received date / time, company code, currency and amount fields of ZCD_PAYM_REQ_LOG and the transaction field are VERIFY-SE11 (docs/USAA_Known_Tables.md); the SUCCESS-row rule is applied (never the highest COUNTER)
// RequestReference: V82 VERIFY-SE11
// BusinessDate: V82 VERIFY-SE11
// ReceivedAt: V82 VERIFY-SE11
// CompanyCode: V82 VERIFY-SE11
// TransactionType: V83 VERIFY-SE11 (exists - user 2026-11-11)
// FeederReference: V89 VERIFY-SE11; masked by default (feeder row REF_VISIBLE blank)
// RequestStatus: V84 lifecycle status not named
// Currency: V82 VERIFY-SE11 (TRACE_SRC_REQUEST AMOUNT=)
// Amount: V82 VERIFY-SE11 (TRACE_SRC_REQUEST AMOUNT=)
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment model - adapter payment request'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
define view entity ZI_CD_PaymReqFact
  as select from zcd_paym_req_log as Log
{
  key cast( Log.‹FIN number field› as abap.char( 40 ) ) as RequestReference,
      Log.‹received date field› as BusinessDate,
      Log.‹received time stamp field› as ReceivedAt,
      Log.‹company code field› as CompanyCode,
      Log.source as Source,
      Log.‹transaction field› as TransactionType,
      Log.‹feeder business reference field (claim / policy / invoice)› as FeederReference,
      cast( '' as abap.char( 20 ) ) as RequestStatus,
      Log.zz_status as ProcessingStatus,
      Log.‹currency field› as Currency,
      @Semantics.amount.currencyCode: 'Currency'
      Log.‹amount field› as Amount
}
where
      Log.zz_status = 'SUCCESS'

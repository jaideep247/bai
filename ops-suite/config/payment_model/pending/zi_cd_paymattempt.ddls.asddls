// Artifact: zi_cd_paymattempt.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Payment model of the ops suite - ADAPTER of the request attempt: the contract fields of the product
//          (docs/ADDING_A_CUSTOMER_PAYMENT_MODEL.md) mapped to this landscape by the mapping spec config/payment_model/mapping.json.
// Modification log: 2026-11-11 | Generated from the mapping spec (payment model).
// PENDING (not imported): V82: FIN-number, company code and received time fields of ZCD_PAYM_REQ_LOG are VERIFY-SE11
// RequestReference: V82 VERIFY-SE11
// CompanyCode: V82 VERIFY-SE11
// ReceivedAt: V82 VERIFY-SE11
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment model - adapter request attempt'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
define view entity ZI_CD_PaymAttempt
  as select from zcd_paym_req_log as Log
{
  key cast( Log.‹FIN number field› as abap.char( 40 ) ) as RequestReference,
  key Log.counter as AttemptNumber,
      Log.‹company code field› as CompanyCode,
      Log.zz_status as ProcessingStatus,
      Log.‹received time stamp field› as ReceivedAt,
      cast( case when Log.zz_status = 'SUCCESS' then 'X' else ' ' end as abap_boolean ) as IsAccepted
}

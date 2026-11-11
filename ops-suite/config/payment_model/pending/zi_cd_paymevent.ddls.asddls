// Artifact: zi_cd_paymevent.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Payment model of the ops suite - ADAPTER of the request timeline: the contract fields of the product
//          (docs/ADDING_A_CUSTOMER_PAYMENT_MODEL.md) mapped to this landscape by the mapping spec config/payment_model/mapping.json.
// Modification log: 2026-11-11 | Generated from the mapping spec (payment model).
// PENDING (not imported): V90: the hops need a consumer union view (request log received time, PRISM status API / FMON event of the request's file, payment run, ZCD_SPE_EXCP_LOG status sent back) - the link request -> file and every SPE field are VERIFY-SE11
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment model - adapter request timeline'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
define view entity ZI_CD_PaymEvent
  as select from ‹ZI_CD_PaymHops - union of the hops, built after SE11› as Hop
{
  key Hop.RequestReference as RequestReference,
  key Hop.EventSequence as EventSequence,
      Hop.CompanyCode as CompanyCode,
      Hop.EventAt as EventAt,
      Hop.Hop as Hop,
      Hop.EventStatus as EventStatus,
      Hop.EventReference as EventReference
}

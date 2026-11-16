// Artifact: zi_xx_paymreqfact.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Payment model of the example customer XX (intake) - ADAPTER of the payment request: the contract fields of the product
//          (docs/ADDING_A_CUSTOMER_PAYMENT_MODEL.md) mapped to this landscape by the mapping spec config/payment_model/mapping.json.
// Modification log: 2026-11-16 | Generated from the mapping spec (payment model).
// ReceivedAt: the intake keeps the date only
// TransactionType: not kept in the intake of XX
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment model - adapter payment request'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
define view entity ZI_XX_PaymReqFact
  as select from zxx_intake as Ink
{
  key cast( Ink.intake_id as abap.char( 40 ) ) as RequestReference,
      Ink.received_on as BusinessDate,
      cast( 0 as abap.dec( 21, 7 ) ) as ReceivedAt,
      Ink.bukrs as CompanyCode,
      Ink.logsys as Source,
      cast( '' as abap.char( 20 ) ) as TransactionType,
      cast( Ink.pay_ref as abap.char( 40 ) ) as FeederReference,
      Ink.status as RequestStatus,
      Ink.status as ProcessingStatus,
      cast( Ink.waers as abap.cuky ) as Currency,
      @Semantics.amount.currencyCode: 'Currency'
      cast( Ink.amount as abap.curr( 23, 2 ) ) as Amount
}

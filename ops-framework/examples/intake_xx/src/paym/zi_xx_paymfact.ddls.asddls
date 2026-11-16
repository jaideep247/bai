// Artifact: zi_xx_paymfact.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Payment model of the example customer XX (intake) - ADAPTER of the payment fact: the contract fields of the product
//          (docs/ADDING_A_CUSTOMER_PAYMENT_MODEL.md) mapped to this landscape by the mapping spec config/payment_model/mapping.json.
// Modification log: 2026-11-16 | Generated from the mapping spec (payment model).
// CompanyCurrency: not kept in the payment register of XX
// TransactionType: not kept in the payment register of XX
// RequestStatus: on the request page (intake status)
// MethodClass: no method class at XX
// Outcome: no outcome register at XX
// Finding: exceptions are read from the product's findings
// IsLate: no due time in the payment register of XX
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment model - adapter payment fact'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
define view entity ZI_XX_PaymFact
  as select from zxx_payment as Pay
{
  key Pay.pay_date as BusinessDate,
  key Pay.run_id as PaymentRun,
  key Pay.pay_doc as PaymentDocument,
      Pay.bukrs as CompanyCode,
      cast( '' as abap.cuky ) as CompanyCurrency,
      Pay.flow as Flow,
      Pay.feeder as Source,
      cast( '' as abap.char( 20 ) ) as TransactionType,
      cast( '' as abap.char( 20 ) ) as RequestStatus,
      Pay.pay_status as PaymentStatus,
      Pay.pay_method as PaymentMethod,
      cast( '' as abap.char( 3 ) ) as MethodClass,
      Pay.house_bank as HouseBank,
      Pay.account_id as HouseBankAccount,
      cast( '' as abap.char( 20 ) ) as Outcome,
      cast( '' as abap.char( 30 ) ) as Finding,
      cast( ' ' as abap_boolean ) as IsLate,
      cast( Pay.waers as abap.cuky ) as Currency,
      @Semantics.amount.currencyCode: 'Currency'
      cast( Pay.amount as abap.curr( 23, 2 ) ) as Amount
}

// Artifact: zc_xx_payment.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Payment model of the example customer XX (intake) - individual payment (entity Payment of ZUI_XX_PAYM): drill-down list
//          of a category card (business date mandatory, paged) and the payment object page with its requests and
//          the links to the payment trace, the exceptions and the job of its run. Read access: DCL ZC_XX_PAYM.
// Modification log: 2026-11-16 | Generated from the product template (payment model).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Payment model - payment'
@Metadata.allowExtensions: true
define root view entity ZC_XX_Payment
  provider contract transactional_query
  as projection on ZR_XX_Payment
{
  key BusinessDate,
  key PaymentRun,
  key PaymentDocument,
      _Requests : redirected to ZC_XX_PaymReqLink,
      CompanyCode,
      OpsArea,
      @ObjectModel.text.element: [ 'FlowText' ]
      Flow,
      @Semantics.text: true
      FlowText,
      @ObjectModel.text.element: [ 'FeederName' ]
      Source,
      @Semantics.text: true
      FeederName,
      TransactionType,
      RequestStatus,
      @ObjectModel.text.element: [ 'PaymentStatusText' ]
      PaymentStatus,
      @Semantics.text: true
      PaymentStatusText,
      PaymentMethod,
      @ObjectModel.text.element: [ 'MethodClassText' ]
      MethodClass,
      @Semantics.text: true
      MethodClassText,
      HouseBank,
      HouseBankAccount,
      Outcome,
      Finding,
      IsLate,
      Currency,
      @Semantics.amount.currencyCode: 'Currency'
      Amount,
      CompanyCurrency
}

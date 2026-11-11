// Artifact: zc_{{p}}_payment.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Payment model of the {{CONSUMER}} - individual payment (entity Payment of {{SERVICE}}): drill-down list
//          of a category card (business date mandatory, paged) and the payment object page with its requests and
//          the links to the payment trace, the exceptions and the job of its run. Read access: DCL ZC_{{P}}_PAYM.
// Modification log: {{SINCE}} | Generated from the product template (payment model).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Payment model - payment'
@Metadata.allowExtensions: true
define root view entity ZC_{{P}}_Payment
  provider contract transactional_query
  as projection on ZR_{{P}}_Payment
{
  key BusinessDate,
  key PaymentRun,
  key PaymentDocument,
#if LINK
      _Requests : redirected to ZC_{{P}}_PaymReqLink,
#endif
#if LEDGER
      _Ledger   : redirected to ZC_{{P}}_PaymLedger,
#endif
#if CHANGES
      _Changes  : redirected to ZC_{{P}}_PaymChange,
#endif
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

// Artifact: zc_cd_paymcube.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Payment model of the ops suite - categorisation cube for the persona overview pages (entity
//          PaymentCategory of ZUI_CD_PAYM): counts and amounts per currency by source, transaction, request
//          status, payment status, method class, company code, house bank and business date. Measures are summed
//          by $apply on the database; Amount is always grouped with its Currency. Read access: DCL
//          ZC_CD_PAYM (area CD_OPS and the company code of the row). Read-only.
// Modification log: 2026-11-11 | Generated from the product template (payment model).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Payment model - categorisation'
@Metadata.allowExtensions: true
define root view entity ZC_CD_PaymCube
  provider contract transactional_query
  as projection on ZR_CD_PaymCube
{
  key BusinessDate,
  key CompanyCode,
      @ObjectModel.text.element: [ 'FlowText' ]
  key Flow,
      @ObjectModel.text.element: [ 'SourceText' ]
  key Source,
      @ObjectModel.text.element: [ 'TransactionText' ]
  key TransactionType,
  key RequestStatus,
      @ObjectModel.text.element: [ 'PaymentStatusText' ]
  key PaymentStatus,
  key PaymentMethod,
      @ObjectModel.text.element: [ 'MethodClassText' ]
  key MethodClass,
  key HouseBank,
  key Outcome,
  key Finding,
  key Currency,
      OpsArea,
      @Semantics.text: true
      FlowText,
      @Semantics.text: true
      SourceText,
      @Semantics.text: true
      TransactionText,
      @Semantics.text: true
      PaymentStatusText,
      @Semantics.text: true
      MethodClassText,
      IsLocalCurrency,
      IsCurrentDay,
      @Aggregation.default: #SUM
      ItemCount,
      @Aggregation.default: #SUM
      LateCount,
      @Aggregation.default: #SUM
      OnTimeCount,
      @Aggregation.default: #SUM
      @Semantics.amount.currencyCode: 'Currency'
      Amount
}

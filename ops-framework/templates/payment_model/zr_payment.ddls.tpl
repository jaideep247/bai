// Artifact: zr_{{p}}_payment.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Payment model of the {{CONSUMER}} - one payment (drill-down list and object page): the adapter row of
//          ZI_{{P}}_PaymFact with the dimension texts and the feeder system name, and the requests it settled
//          (association _Requests, 1:n - a payment can settle several requests and a request can be paid by
//          several payments). Read by key or with a business date (the list makes the date mandatory) - never
//          a scan of the payment table. Read-only.
// Modification log: {{SINCE}} | Generated from the product template (payment model).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment model - payment'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
define root view entity ZR_{{P}}_Payment
  as select from    ZI_{{P}}_PaymFact  as Fact
    left outer join ZI_CA_PaymDimText  as FlowT on  FlowT.Language  = $session.system_language
                                                and FlowT.Dimension = 'FLOW'
                                                and FlowT.DimValue  = Fact.Flow
    left outer join ZI_CA_PaymDimText  as PstT  on  PstT.Language   = $session.system_language
                                                and PstT.Dimension  = 'PAY_STATUS'
                                                and PstT.DimValue   = Fact.PaymentStatus
    left outer join ZI_CA_PaymDimText  as MclT  on  MclT.Language   = $session.system_language
                                                and MclT.Dimension  = 'METHOD_CLASS'
                                                and MclT.DimValue   = Fact.MethodClass
    left outer join ZI_CA_PaymFeeder   as Fdr   on  Fdr.Feeder      = Fact.Source
#if LINK
  association [0..*] to ZR_{{P}}_PaymReqLink as _Requests on $projection.PaymentDocument = _Requests.PaymentDocument
#endif
{
  key Fact.BusinessDate,
  key Fact.PaymentRun,
  key Fact.PaymentDocument,
#if LINK
      _Requests,
#endif
      Fact.CompanyCode,
      cast( '{{AREA}}' as abap.char( 16 ) )                 as OpsArea,
      Fact.Flow,
      FlowT.DimText                                         as FlowText,
      Fact.Source,
      Fdr.FeederName,
      Fact.TransactionType,
      Fact.RequestStatus,
      Fact.PaymentStatus,
      PstT.DimText                                          as PaymentStatusText,
      Fact.PaymentMethod,
      Fact.MethodClass,
      MclT.DimText                                          as MethodClassText,
      Fact.HouseBank,
      Fact.HouseBankAccount,
      Fact.Outcome,
      Fact.Finding,
      Fact.IsLate,
      Fact.Currency,
      @Semantics.amount.currencyCode: 'Currency'
      Fact.Amount,
      Fact.CompanyCurrency
}

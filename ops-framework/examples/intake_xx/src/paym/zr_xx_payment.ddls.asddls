// Artifact: zr_xx_payment.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Payment model of the example customer XX (intake) - one payment (drill-down list and object page): the adapter row of
//          ZI_XX_PaymFact with the dimension texts and the feeder system name, and the requests it settled
//          (association _Requests, 1:n - a payment can settle several requests and a request can be paid by
//          several payments), its ledger (association _Ledger: share of the subledger batch summary, G/L documents and
//          journal lines - ledger model) and its document changes (_Changes: reversal, clearing reset, re-clearing, void,
//          reissue, G/L reversal - document-change model). Read by key or with a business date (the list makes the date mandatory) - never
//          a scan of the payment table. Read-only.
// Modification log: 2026-11-16 | Generated from the product template (payment model).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment model - payment'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
define root view entity ZR_XX_Payment
  as select from    ZI_XX_PaymFact  as Fact
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
  association [0..*] to ZR_XX_PaymReqLink as _Requests on $projection.PaymentDocument = _Requests.PaymentDocument
{
  key Fact.BusinessDate,
  key Fact.PaymentRun,
  key Fact.PaymentDocument,
      _Requests,
      Fact.CompanyCode,
      cast( 'ZXX_OPS' as abap.char( 16 ) )                 as OpsArea,
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

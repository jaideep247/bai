// Artifact: zr_{{p}}_paymcube.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Payment model of the {{CONSUMER}} - categorisation cube: payments of a business date aggregated on the
//          database per company code, flow, source, transaction, request status, payment status, payment method
//          and method class, house bank, open outcome / finding and CURRENCY - count, late / on-time count and
//          the amount per currency (currency is a grouping key: two currencies are never added, no conversion).
//          Dimension texts from the framework (ZI_CA_PaymDimText, language of the session); current business
//          date from ZI_CA_OpsBusDay (control time zone). Base: the adapter ZI_{{P}}_PaymFact of the mapping
//          spec (contract of docs/ADDING_A_CUSTOMER_PAYMENT_MODEL.md). No row per payment reaches the UI.
// Modification log: {{SINCE}} | Generated from the product template (payment model).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment model - categorisation cube'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define root view entity ZR_{{P}}_PaymCube
  as select from    ZI_{{P}}_PaymFact  as Fact
    left outer join ZI_CA_OpsBusDay    as Day   on  Day.BusinessDate = Fact.BusinessDate
    left outer join ZI_CA_PaymDimText  as FlowT on  FlowT.Language  = $session.system_language
                                                and FlowT.Dimension = 'FLOW'
                                                and FlowT.DimValue  = Fact.Flow
    left outer join ZI_CA_PaymDimText  as SrcT  on  SrcT.Language   = $session.system_language
                                                and SrcT.Dimension  = 'SOURCE'
                                                and SrcT.DimValue   = Fact.Source
    left outer join ZI_CA_PaymDimText  as TxnT  on  TxnT.Language   = $session.system_language
                                                and TxnT.Dimension  = 'TRANSACTION'
                                                and TxnT.DimValue   = Fact.TransactionType
    left outer join ZI_CA_PaymDimText  as PstT  on  PstT.Language   = $session.system_language
                                                and PstT.Dimension  = 'PAY_STATUS'
                                                and PstT.DimValue   = Fact.PaymentStatus
    left outer join ZI_CA_PaymDimText  as MclT  on  MclT.Language   = $session.system_language
                                                and MclT.Dimension  = 'METHOD_CLASS'
                                                and MclT.DimValue   = Fact.MethodClass
{
  key Fact.BusinessDate,
  key Fact.CompanyCode,
  key Fact.Flow,
  key Fact.Source,
  key Fact.TransactionType,
  key Fact.RequestStatus,
  key Fact.PaymentStatus,
  key Fact.PaymentMethod,
  key Fact.MethodClass,
  key Fact.HouseBank,
  key Fact.Outcome,
  key Fact.Finding,
  key Fact.Currency,
      cast( '{{AREA}}' as abap.char( 16 ) )                 as OpsArea,
      FlowT.DimText                                         as FlowText,
      SrcT.DimText                                          as SourceText,
      TxnT.DimText                                          as TransactionText,
      PstT.DimText                                          as PaymentStatusText,
      MclT.DimText                                          as MethodClassText,
      cast( case when Fact.Currency = Fact.CompanyCurrency then 'X' else ' ' end as abap_boolean ) as IsLocalCurrency,
      cast( case when Day.IsCurrentDay = 'X' then 'X' else ' ' end as abap_boolean ) as IsCurrentDay,
      cast( count( * ) as abap.int4 )                       as ItemCount,
      cast( sum( case when Fact.IsLate = 'X' then 1 else 0 end ) as abap.int4 ) as LateCount,
      cast( sum( case when Fact.IsLate = 'X' then 0 else 1 end ) as abap.int4 ) as OnTimeCount,
      @Semantics.amount.currencyCode: 'Currency'
      sum( Fact.Amount )                                    as Amount
}
group by
  Fact.BusinessDate,
  Fact.CompanyCode,
  Fact.Flow,
  Fact.Source,
  Fact.TransactionType,
  Fact.RequestStatus,
  Fact.PaymentStatus,
  Fact.PaymentMethod,
  Fact.MethodClass,
  Fact.HouseBank,
  Fact.Outcome,
  Fact.Finding,
  Fact.Currency,
  Fact.CompanyCurrency,
  Day.IsCurrentDay,
  FlowT.DimText,
  SrcT.DimText,
  TxnT.DimText,
  PstT.DimText,
  MclT.DimText

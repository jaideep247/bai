// Artifact: zi_cd_paymfact.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Payment model of the ops suite - ADAPTER of the payment fact: the contract fields of the product
//          (docs/ADDING_A_CUSTOMER_PAYMENT_MODEL.md) mapped to this landscape by the mapping spec config/payment_model/mapping.json.
//          Base: ZI_CD_PayLifeRun - the newest non-proposal DPAYH row of every payment document, run date LAUFD in the
//          last 45 days (key range of the DPAYH primary index; Performance_Review.md section 11). Flow from TFK042Z-XEINZ of
//          the company code country, method class from posting area ZPMC (ZI_CD_PayMethodCls), source / outcome / finding
//          / late from the payment worklist (ZI_CD_PayWorkState; a clean payment has none - source unknown bucket).
// Modification log: 2026-11-11 | Generated from the mapping spec (payment model).
// CompanyCode: VERIFY-SE11 DPAYH-BUKRS (as ZI_CD_PayLifeRun)
// CompanyCurrency: Released view I_CompanyCode (C1, VERIFY.md V110) - Currency, Country (country of TFK042Z); TFK042Z stays a table read (no released view)
// TransactionType: V83: transaction of the request (field of ZCD_PAYM_REQ_LOG confirmed by the user 2026-11-11, name VERIFY-SE11) - reached through the request (pending section); blank until then
// RequestStatus: V84: business request lifecycle status (PENDING / SCHEDULED / SRCPOSTED / source reject) - no confirmed table / field (control_seed.md section 2a P2)
// PaymentMethod: VERIFY-SE11 DPAYH-PYMET (as ZI_CD_PayLifeRun)
// HouseBank: VERIFY-SE11 DPAYH-HBKID (as ZI_CD_PayLifeRun)
// HouseBankAccount: V87: DPAYH-HKTID (account ID, never the bank account number) not yet confirmed - blank until SE11
// Currency: VERIFY-SE11 DPAYH-WAERS (as ZI_CD_PayLifeRun)
// Amount: absolute DPAYH-RWBTR (as ZI_CD_PayLifeRun); sign = flow
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment model - adapter payment fact'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
define view entity ZI_CD_PaymFact
  as select from ZI_CD_PayLifeRun as Pay
    left outer join I_CompanyCode      as Cc  on  Cc.CompanyCode  = Pay.CompanyCode
    left outer join tfk042z            as Pm  on  Pm.land1        = Cc.Country
                                              and Pm.zlsch        = Pay.PaymentMethod
    left outer join ZI_CD_PayMethodCls as McC on  McC.Flow        = 'C'
                                              and McC.PaymentMethod = Pay.PaymentMethod
    left outer join ZI_CD_PayMethodCls as McD on  McD.Flow        = 'D'
                                              and McD.PaymentMethod = Pay.PaymentMethod
    left outer join ZI_CD_PayWorkState as Ws  on  Ws.ClearingDoc  = Pay.PaymentDocument
{
  key Pay.BusinessDate as BusinessDate,
  key Pay.RunId as PaymentRun,
  key Pay.PaymentDocument as PaymentDocument,
      Pay.CompanyCode as CompanyCode,
      Cc.Currency as CompanyCurrency,
      cast( case when Pm.xeinz = 'X' then 'C' when Pm.zlsch is null then ' ' else 'D' end as abap.char( 1 ) ) as Flow,
      cast( coalesce( Ws.SourceSystem, ' ' ) as abap.char( 10 ) ) as Source,
      cast( '' as abap.char( 20 ) ) as TransactionType,
      cast( '' as abap.char( 20 ) ) as RequestStatus,
      Pay.PaymentStatus as PaymentStatus,
      Pay.PaymentMethod as PaymentMethod,
      cast( case when Pm.xeinz = 'X' then McC.MethodClass else McD.MethodClass end as abap.char( 3 ) ) as MethodClass,
      Pay.HouseBank as HouseBank,
      cast( '' as abap.char( 5 ) ) as HouseBankAccount,
      cast( coalesce( Ws.Outcome, ' ' ) as abap.char( 20 ) ) as Outcome,
      cast( coalesce( Ws.Finding, ' ' ) as abap.char( 30 ) ) as Finding,
      cast( coalesce( Ws.IsLate, ' ' ) as abap_boolean ) as IsLate,
      Pay.Currency as Currency,
      @Semantics.amount.currencyCode: 'Currency'
      Pay.Amount as Amount
}

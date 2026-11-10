// Artifact: zr_cd_payofday.ddls.asddls
// Purpose: "View payments" of the payment lifecycle card: the payments of a business date (newest
//          non-proposal run row per payment document, ZI_CD_PayLifeRun) with payment reference (payment
//          document), request source (when the worklist has a row, ZI_CD_PayWorkSrc), company code, method,
//          house bank, live status with its configured stage, amount. Live from DPAYH and the worklist, no
//          copy; company-code authorisation on the row (DCL ZC_CD_OPSOVERVIEW). No member, partner or bank
//          account is selected. The payment document opens the payment trace. Read-only.
// Modification log: 2026-11-10 | Initial version (control center: payment lifecycle list).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Production support - payments of a date'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
define root view entity ZR_CD_PayOfDay
  as select from    ZI_CD_PayLifeRun as Pay
    left outer join ZI_CD_PayWorkSrc as Src   on  Src.ClearingDoc = Pay.PaymentDocument
    left outer join zcd_ops_paystage as Stage on  Stage.source      = 'PAYRUN'
                                              and Stage.match_value = Pay.PaymentStatus
                                              and Stage.active      = 'X'
    left outer join ZI_CA_OpsBusDay  as Day   on  Day.BusinessDate = Pay.BusinessDate
{
  key Pay.BusinessDate,
  key Pay.RunId,
  key Pay.PaymentDocument,
      cast( Pay.CompanyCode as abap.char( 4 ) )             as CompanyCode,
      cast( 'CD_OPS' as abap.char( 16 ) )                   as PaymentEngineArea,
      Src.SourceSystem,
      Pay.PaymentMethod,
      Pay.HouseBank,
      Pay.PaymentStatus,
      Stage.stage                                           as Stage,
      Stage.label                                           as StageLabel,
      Pay.Currency,
      @Semantics.amount.currencyCode: 'Currency'
      Pay.Amount,
      cast( case when Day.IsCurrentDay = 'X' then 'X' else ' ' end as abap_boolean ) as IsCurrentDay,
      cast( 1 as abap.int4 )                                as PaymentCount
}

// Artifact: zr_cd_docevtcube.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Document-change model of the ops suite - volumes of document changes (entity DocumentChangeCategory):
//          per event date, change type, source of the change (subledger / payment run / G/L), company code, feeder
//          source, payment type (method class), house bank and currency of the payment: number of changes, payments and
//          the payment amount (absolute, per currency - never across currencies). The payment's dimensions come from the
//          payment fact (window of the payment model); a change of a payment outside the window keeps blank
//          dimensions. No user dimension (user IDs only on the payment's timeline). Aggregated in the database.
// Modification log: 2026-11-11 | Generated from the product template (document-change model).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Document-change model - volumes'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define root view entity ZR_CD_DocEvtCube
  as select from    ZI_CD_DocEvtAll as Evt
    left outer join ZI_CD_PaymFact  as Pay on Pay.PaymentDocument = Evt.PaymentDocument
{
  key Evt.EventDate,
  key Evt.EventType,
  key Evt.EventSource,
  key Evt.CompanyCode,
  key cast( coalesce( Pay.Source, '' ) as abap.char( 10 ) )      as Source,
  key cast( coalesce( Pay.MethodClass, '' ) as abap.char( 3 ) )  as MethodClass,
  key cast( coalesce( Pay.HouseBank, '' ) as abap.char( 5 ) )    as HouseBank,
  key cast( coalesce( Pay.Currency, '' ) as abap.cuky )          as Currency,
      cast( 'CD_OPS' as abap.char( 16 ) )                 as OpsArea,
      cast( count( * ) as abap.int4 )                       as EventCount,
      cast( count( distinct Evt.PaymentDocument ) as abap.int4 ) as PaymentCount,
      cast( sum( cast( coalesce( Pay.Amount, 0 ) as abap.dec( 23, 2 ) ) ) as abap.dec( 23, 2 ) ) as PaymentAmount
}
group by
  Evt.EventDate,
  Evt.EventType,
  Evt.EventSource,
  Evt.CompanyCode,
  Pay.Source,
  Pay.MethodClass,
  Pay.HouseBank,
  Pay.Currency

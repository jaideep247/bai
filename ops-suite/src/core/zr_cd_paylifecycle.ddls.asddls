// Artifact: zr_cd_paylifecycle.ddls.asddls
// Purpose: "Payment lifecycle" card of the overview page: tracked payments (and payment requests) of a
//          business date per configured stage - the active rows of ZCD_OPS_PAYSTAGE (order SEQ, label LABEL,
//          source PAYRUN / REQUEST, counted value MATCH_VALUE) joined to the live counts of
//          ZI_CD_PayLifeCntU; per company code (authorisation on the base rows). A stage without a payment on
//          the date has no row (no bar). Current business date (IsCurrentDay) in CONTROL_TIME_ZONE
//          (ZI_CA_OpsBusDay, 31 days). Nothing is stored. Read-only.
// Modification log: 2026-11-10 | Initial version (control center: payment lifecycle).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Production support - payment lifecycle'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #M, dataClass: #TRANSACTIONAL }
define root view entity ZR_CD_PayLifecycle
  as select from    zcd_ops_paystage  as Stage
    inner join      ZI_CD_PayLifeCntU as Cnt on  Cnt.StageSource = Stage.source
                                             and Cnt.MatchValue  = Stage.match_value
    left outer join ZI_CA_OpsBusDay   as Day on  Day.BusinessDate = Cnt.BusinessDate
{
  key Cnt.BusinessDate,
  key Cnt.CompanyCode,
  key Stage.stage                                           as Stage,
      Stage.seq                                             as StageSequence,
      Stage.label                                           as StageLabel,
      Stage.source                                          as StageSource,
      cast( 'CD_OPS' as abap.char( 16 ) )                   as PaymentEngineArea,
      cast( case when Day.IsCurrentDay = 'X' then 'X' else ' ' end as abap_boolean ) as IsCurrentDay,
      cast( sum( Cnt.PaymentCount ) as abap.int4 )          as PaymentCount
}
where
  Stage.active = 'X'
group by
  Cnt.BusinessDate,
  Cnt.CompanyCode,
  Stage.stage,
  Stage.seq,
  Stage.label,
  Stage.source,
  Day.IsCurrentDay

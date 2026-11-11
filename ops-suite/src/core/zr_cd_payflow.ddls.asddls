// Artifact: zr_cd_payflow.ddls.asddls
// Purpose: "Process flow" card of the overview page: the payment lifecycle of a business date and company code per
//          configured stage (ZCD_OPS_PAYSTAGE order) - payments now in the stage (ZR_CD_PayLifecycle), how many of
//          them are STUCK (older than the stage's expected time STUCK_DAYS: calendar days since the business date =
//          run date of a payment / due date of a request - the age of a status is not stored, so the age of the
//          payment is used), payments that reached the stage, and the DROP from the previous stage (reached there,
//          not here). Criticality: 0 no expected time (final stage), 3 none stuck, 2 stuck, 1 stuck for more than
//          twice the expected time. The first stage of a source has no drop. Stage sequences are unique (the
//          configuration app orders the card by them). Live, nothing stored. Read-only.
// Modification log: 2026-11-11 | Initial version (process flow card of the overview page).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Production support - process flow'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #M, dataClass: #TRANSACTIONAL }
define root view entity ZR_CD_PayFlow
  as select from    ZR_CD_PayLifecycle as Life
    inner join      zcd_ops_paystage   as Stage on  Stage.stage        = Life.Stage
    left outer join ZI_CD_PayFlowReach as Reach on  Reach.BusinessDate = Life.BusinessDate
                                                and Reach.CompanyCode  = Life.CompanyCode
                                                and Reach.Stage        = Life.Stage
    left outer join ZI_CD_PayStagePrev as Prev  on  Prev.Stage         = Life.Stage
    left outer join ZI_CD_PayFlowReach as Before on  Before.BusinessDate  = Life.BusinessDate
                                                 and Before.CompanyCode   = Life.CompanyCode
                                                 and Before.StageSequence = Prev.PrevSequence
{
  key Life.BusinessDate,
  key Life.CompanyCode,
  key Life.Stage,
      Life.StageSequence,
      Life.StageLabel,
      Life.StageSource,
      Life.PaymentEngineArea,
      Life.IsCurrentDay,
      Stage.stuck_days                                      as StuckAfterDays,
      dats_days_between( Life.BusinessDate, $session.system_date ) as AgeDays,
      Life.PaymentCount,
      cast( case when Stage.stuck_days > 0
                  and dats_days_between( Life.BusinessDate, $session.system_date ) > Stage.stuck_days
                 then Life.PaymentCount else 0 end as abap.int4 ) as StuckCount,
      cast( coalesce( Reach.ReachedCount, 0 ) as abap.int4 ) as ReachedCount,
      cast( case when Prev.PrevSequence is null then 0
                 else coalesce( Before.ReachedCount, 0 ) - coalesce( Reach.ReachedCount, 0 ) end as abap.int4 ) as DropCount,
      cast( case when Stage.stuck_days <= 0 then 0
                 when dats_days_between( Life.BusinessDate, $session.system_date ) > 2 * Stage.stuck_days then 1
                 when dats_days_between( Life.BusinessDate, $session.system_date ) > Stage.stuck_days then 2
                 else 3 end as abap.int1 )                  as FlowCriticality
}

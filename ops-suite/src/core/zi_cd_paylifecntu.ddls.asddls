// Artifact: zi_cd_paylifecntu.ddls.asddls
// Purpose: Counts behind the payment lifecycle card, per business date, company code and counted value:
//          PAYRUN - payments of the date (ZI_CD_PayLifeRun) per live payment status; REQUEST - current
//          payment request rows of the worklist (ZCD_PAY_OUTCOME, VALID_TO open, no payment document) due on
//          the date, per outcome (e.g. REQ_OPEN) and per stage (evidence kind, e.g. PRQ_NOT_IN_RUN). The
//          stages of ZCD_OPS_PAYSTAGE pick the values they show (ZR_CD_PayLifecycle). Aggregated on the
//          database (indexes: DPAYH key LAUFD; worklist index DUE). Read-only.
// Modification log: 2026-11-10 | Initial version (control center: payment lifecycle).
// VERIFY-ADT: UNION ALL of three aggregating selects in a CDS view entity (7.58); fallback: three views.
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment lifecycle - counts per value'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define view entity ZI_CD_PayLifeCntU
  as select from ZI_CD_PayLifeRun
{
  key cast( 'PAYRUN' as abap.char( 10 ) )                   as StageSource,
  key BusinessDate,
  key cast( CompanyCode as abap.char( 4 ) )                 as CompanyCode,
  key cast( PaymentStatus as abap.char( 30 ) )              as MatchValue,
      cast( count( * ) as abap.int4 )                       as PaymentCount
}
group by
  BusinessDate,
  CompanyCode,
  PaymentStatus

union all

select from ZI_CD_PayOutcome
{
  key cast( 'REQUEST' as abap.char( 10 ) )                  as StageSource,
  key DueDate                                               as BusinessDate,
  key cast( CompanyCode as abap.char( 4 ) )                 as CompanyCode,
  key cast( Outcome as abap.char( 30 ) )                    as MatchValue,
      cast( count( * ) as abap.int4 )                       as PaymentCount
}
where
      ValidTo     = 99991231235959
  and ClearingDoc = ' '
  and DueDate     >= dats_add_days( $session.system_date, -45, 'INITIAL' )
group by
  DueDate,
  CompanyCode,
  Outcome

union all

select from ZI_CD_PayOutcome
{
  key cast( 'REQUEST' as abap.char( 10 ) )                  as StageSource,
  key DueDate                                               as BusinessDate,
  key cast( CompanyCode as abap.char( 4 ) )                 as CompanyCode,
  key cast( EvidenceKind as abap.char( 30 ) )               as MatchValue,
      cast( count( * ) as abap.int4 )                       as PaymentCount
}
where
      ValidTo      =  99991231235959
  and ClearingDoc  =  ' '
  and EvidenceKind <> ' '
  and DueDate      >= dats_add_days( $session.system_date, -45, 'INITIAL' )
group by
  DueDate,
  CompanyCode,
  EvidenceKind

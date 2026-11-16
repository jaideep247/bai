// Artifact: zr_ca_opspayfile.ddls.asddls
// Purpose: Payment file lifecycle - one row per payment file and currency (ZCA_OPS_PFFILE with ZI_CA_OpsPfFileCur; a
//          file without known payments has one row with a blank currency): where the file stopped (last milestone
//          reached, next required milestone, state), payments, gross amount, payments without a known amount and the
//          possible duplicate exposure in that currency, deadline and minutes overdue, business calendar, age, the
//          responsible owner (open exception of the file: user / team of the exception contract; else the owner of
//          the file type's business process), the evaluation (complete, partial, not evaluated, stale) with its
//          reason and last valid state, the reissue (predecessor) and the job. Base view of the worklist
//          ZC_CA_OpsPayFile; associations to the payments, the milestones (stage timeline) and the evidence.
// Modification log: 2026-11-15 | Initial version (build K: payment file lifecycle).
// Extension point PAYFILE (2026-11-15; config/extension_points.json, docs/EXTENDING_WITH_CUSTOMER_DATA.md): base view; a
//          customer adds its own elements with extend view entity from its package, never by changing this view.
//          Anchors COMPANY, FILE: their elements stay stable.
// VERIFY-ADT (V153): the extensibility annotations below on 7.58. VERIFY-ADT (V178): concat of the object key.
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment files'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #L, dataClass: #TRANSACTIONAL }
@AbapCatalog.extensibility.extensible: true
@AbapCatalog.extensibility.elementSuffix: 'ZOP'
@AbapCatalog.extensibility.allowNewDatasources: true
@AbapCatalog.extensibility.dataSources: [ 'Fil' ]
@AbapCatalog.extensibility.quota.maximumFields: 50
@AbapCatalog.extensibility.quota.maximumBytes: 2000
define root view entity ZR_CA_OpsPayFile
  as select from    zca_ops_pffile     as Fil
    left outer join ZI_CA_OpsPfFileCur as Cur on  Cur.Area   = Fil.area
                                              and Cur.FileId = Fil.file_id
    left outer join zca_ops_pftyp      as Typ on  Typ.area      = Fil.area
                                              and Typ.file_type = Fil.file_type
    left outer join zca_ops_proc       as Prc on  Prc.area       = Typ.area
                                              and Prc.process_id = Typ.process_id
    left outer join zca_ops_pffile     as Prd on  Prd.area    = Fil.area
                                              and Prd.file_id = Fil.predecessor
  association [0..1] to ZI_CA_OpsPfOpenExc      as _OpenExc    on  $projection.Area      = _OpenExc.Area
                                                               and $projection.ObjectKey = _OpenExc.ObjectKey
  association [0..*] to ZR_CA_OpsPfPayment      as _Payments   on  $projection.Area     = _Payments.Area
                                                               and $projection.FileId   = _Payments.FileId
                                                               and $projection.Currency = _Payments.Currency
  association [0..*] to ZR_CA_OpsPfMilestone    as _Milestones on  $projection.Area   = _Milestones.Area
                                                               and $projection.FileId = _Milestones.FileId
  association [0..*] to ZR_CA_OpsPfEvidence     as _Evidence   on  $projection.Area   = _Evidence.Area
                                                               and $projection.FileId = _Evidence.FileId
{
  key Fil.area                                              as Area,
  key Fil.file_id                                           as FileId,
  key cast( coalesce( Cur.Currency, ' ' ) as abap.char( 5 ) ) as Currency,
      Fil.file_type                                         as FileType,
      Typ.description                                       as FileTypeName,
      Fil.native_key                                        as NativeKey,
      cast( case when Cur.Currency is null or Cur.Currency = ' '
                 then concat( concat( Fil.file_type, '/' ), Fil.native_key )
                 else concat( concat( concat( Fil.file_type, '/' ), Fil.native_key ), concat( '/', Cur.Currency ) )
            end as abap.char( 70 ) )                        as ObjectKey,
      Fil.bukrs                                             as CompanyCode,
      Fil.source_id                                         as SourceId,
      Fil.run_date                                          as RunDate,
      Fil.run_id                                            as RunId,
      Fil.pay_method                                        as PaymentMethod,
      Fil.house_bank                                        as HouseBank,
      Fil.account_id                                        as HouseBankAccount,
      Fil.bus_date                                          as BusinessDate,
      Fil.gen_at                                            as GeneratedAt,
      Fil.gen_job                                           as JobName,
      Fil.gen_jobcount                                      as JobCount,
      // Where the file stopped
      Fil.stage                                             as StageReached,
      Fil.next_ms                                           as NextMilestone,
      Fil.state                                             as State,
      cast( case Fil.state when 'DONE' then 3 when 'OPEN' then case when Fil.overdue_min > 0 then 1 else 2 end
                           when 'REPLACED' then 0 else 1 end as abap.int1 ) as StateCriticality,
      Fil.deadline_at                                       as DeadlineAt,
      Fil.overdue_min                                       as OverdueMinutes,
      Fil.calendar_id                                       as CalendarId,
      dats_days_between( Fil.bus_date, $session.system_date ) as AgeDays,
      // Figures of the currency (never summed across currencies)
      cast( coalesce( Cur.PaymentCount, Fil.pay_count ) as abap.int4 ) as PaymentCount,
      Cur.Amount                                            as Amount,
      cast( coalesce( Cur.UnknownCount, Fil.unknown_count ) as abap.int4 ) as UnknownCount,
      Cur.DuplicateCount                                    as DuplicateCount,
      Cur.DuplicateAmount                                   as DuplicateAmount,
      Fil.pay_count                                         as FilePaymentCount,
      Fil.pay_partial                                       as PaymentsCut,
      // Acknowledgement
      Typ.ack_level                                         as AckLevel,
      Fil.ack_conflict                                      as AckConflict,
      Fil.pay_rejected                                      as PaymentsRejected,
      Fil.pay_open                                          as PaymentsUnanswered,
      Fil.late_ms                                           as LateMilestone,
      Fil.late_min                                          as LateMinutes,
      // Evaluation: C complete, P partial, N not evaluated, S stale
      Fil.eval_state                                        as EvaluationState,
      Fil.eval_reason                                       as EvaluationReason,
      Fil.eval_at                                           as EvaluatedAt,
      Fil.last_valid_at                                     as LastValidAt,
      Fil.last_valid_state                                  as LastValidState,
      // Reissue
      Fil.predecessor                                       as PredecessorId,
      Prd.native_key                                        as PredecessorKey,
      Fil.ticket_ref                                        as TicketReference,
      // Owner from the configuration: the business process of the file type
      Typ.process_id                                        as ProcessId,
      Prc.owner                                             as ProcessOwner,
      _OpenExc,
      _Payments,
      _Milestones,
      _Evidence
}

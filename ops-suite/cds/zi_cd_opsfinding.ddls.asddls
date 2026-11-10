// Artifact: zi_cd_opsfinding.ddls.asddls
// Purpose: Basic interface view over ZCA_OPS_FINDING (findings / owned exceptions
//          of all payment engine areas) with aging. Release-dependent annotations: verify on target release.
// Modification log: 2026-11-05 | Initial version (ops suite consolidation).
//                   2026-11-06 | Amount with currency reference (DECFLOAT34, no TCURX shift);
//                                DaysPastDue only for open / assigned items past due (audit A47, A87).
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Ops suite finding / exception (basic)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #L, dataClass: #TRANSACTIONAL }
@VDM.viewType: #BASIC
define view entity ZI_CD_OpsFinding
  as select from zca_ops_finding
  association [1..1] to ZI_CD_OpsRun as _Run on $projection.RunId = _Run.RunId
{
  key run_id                                              as RunId,
  key finding_no                                          as FindingNo,
      area                                              as PaymentEngineArea,
      object_type                                         as ObjectType,
      object_key                                          as ObjectKey,
      // HCK: category A-E / check id; EBS, FMON: their own grouping
      group1                                              as Group1,
      group2                                              as Group2,
      rule_id                                             as RuleId,
      check_code                                          as CheckCode,
      severity                                            as Severity,
      action                                              as FindingAction,
      // A47: the amount carries its currency. DECFLOAT34 keeps the stored (external) value -
      // a CURR cast would apply the TCURX decimal shift (JPY, KWD ...). VERIFY-ADT on target release
      @Semantics.amount.currencyCode: 'Currency'
      cast( amount as abap.decfloat34 )                   as Amount,
      cast( currency as abap.cuky( 5 ) )                  as Currency,
      reference                                           as Reference,
      message                                             as FindingMessage,
      // O open, A assigned, I information, R resolved, W waived
      disposition                                         as Disposition,
      owner                                               as Owner,
      due_date                                            as DueDate,
      resolved_by                                         as ResolvedBy,
      // verify on target release: TIMESTAMPL -> TIMESTAMP cast, UTC calendar day
      tstmp_to_dats( cast( created_at as timestamp ), 'UTC', $session.client, 'NULL' ) as CreatedDate,
      case when ( disposition = 'O' or disposition = 'A' )
            and due_date <> '00000000'
            and due_date < $session.system_date
           then cast( 'X' as abap_boolean )
           else cast( ' ' as abap_boolean ) end           as IsOverdue,
      // A87: days past due only for open / assigned exceptions that are past due - never
      // negative (not yet due) and never for closed history (resolved, waived, superseded)
      case when ( disposition = 'O' or disposition = 'A' )
            and due_date <> '00000000'
            and due_date < $session.system_date
           then dats_days_between( due_date, $session.system_date )
           else 0 end                                     as DaysPastDue,
      _Run
}

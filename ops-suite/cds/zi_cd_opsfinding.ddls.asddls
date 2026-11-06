// Artifact: zi_cd_opsfinding.ddls.asddls
// Purpose: Basic interface view over ZCD_OPS_FINDING (findings / owned exceptions
//          of all payment engine areas) with aging. Release-dependent annotations: verify on target release.
// Modification log: 2026-11-05 | Initial version (ops suite consolidation).
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Ops suite finding / exception (basic)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #L, dataClass: #TRANSACTIONAL }
@VDM.viewType: #BASIC
define view entity ZI_CD_OpsFinding
  as select from zcd_ops_finding
  association [1..1] to ZI_CD_OpsRun as _Run on $projection.RunId = _Run.RunId
{
  key run_id                                              as RunId,
  key finding_no                                          as FindingNo,
      pe_area                                              as PaymentEngineArea,
      object_type                                         as ObjectType,
      object_key                                          as ObjectKey,
      // HCK: category A-E / check id; EBS, FMON: their own grouping
      group1                                              as Group1,
      group2                                              as Group2,
      rule_id                                             as RuleId,
      check_code                                          as CheckCode,
      severity                                            as Severity,
      action                                              as FindingAction,
      amount                                              as Amount,
      currency                                            as Currency,
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
      case when due_date <> '00000000'
           then dats_days_between( due_date, $session.system_date )
           else 0 end                                     as DaysPastDue,
      _Run
}

// Artifact: zr_cd_opscritexc.ddls.asddls
// Purpose: "Open critical exceptions" card of the production-support overview page: open or
//          assigned findings (ZCD_OPS_FINDING disposition O / A) of severity B (block) or E (error)
//          across all payment engine areas (FMON, EBS, HCK, CORE), with owner, due date, overdue
//          flag and days overdue. GROUP1 is never exposed (EBS statement findings hold the bank
//          account number there); the message of EBS statement / file findings of the bank-file
//          source is not exposed (may contain the account number - same rule as ZI_CD_EbsFinding).
//          Work the exception in the owned-exceptions app (ZUI_CD_OPS_EXC_O4). Read-only.
// Modification log: 2026-11-06 | Initial version (production-support overview page).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Production support - critical exceptions'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #M, dataClass: #TRANSACTIONAL }
define root view entity ZR_CD_OpsCritExc
  as select from zcd_ops_finding
{
  key run_id                                                as RunId,
  key finding_no                                            as FindingNo,
      pe_area                                               as PaymentEngineArea,
      object_type                                           as ObjectType,
      object_key                                            as ObjectKey,
      // Interface / payment method (FMON), category / bank key (EBS), check id (HCK)
      group2                                                as Detail,
      rule_id                                               as RuleId,
      check_code                                            as CheckCode,
      severity                                              as Severity,
      cast( 1 as abap.int1 )                                as SeverityCriticality,
      cast( case when pe_area = 'EBS' and ( object_type = 'STMT' or object_type = 'FILE' )
                  and left( object_key, 3 ) <> 'FEB'
                 then ' ' else message end as abap.char( 255 ) ) as FindingMessage,
      disposition                                           as Disposition,
      owner                                                 as Owner,
      due_date                                              as DueDate,
      case when due_date < $session.system_date and due_date <> '00000000'
           then cast( 'X' as abap_boolean )
           else cast( ' ' as abap_boolean ) end             as IsOverdue,
      cast( case when due_date < $session.system_date and due_date <> '00000000'
                 then dats_days_between( due_date, $session.system_date )
                 else 0 end as abap.int4 )                  as DaysOverdue,
      first_seen_at                                         as FirstSeenAt,
      created_at                                            as CreatedAt,
      cast( 1 as abap.int4 )                                as ExceptionCount
}
where ( disposition = 'O' or disposition = 'A' )
  and ( severity = 'B' or severity = 'E' )

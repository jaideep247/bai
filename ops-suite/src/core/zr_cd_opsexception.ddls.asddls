@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Owned exceptions'
@Metadata.ignorePropagatedAnnotations: true
// Exceptions app (design 6.1): findings of rank >= 2 (B, E, W) that are not superseded
define root view entity ZR_CD_OpsException
  as select from zcd_ops_finding
  composition [0..*] of ZR_CD_OpsExcHist as _History
{
      @EndUserText.label: 'Run'
  key run_id        as RunId,
      @EndUserText.label: 'Finding'
  key finding_no    as FindingNo,
      @EndUserText.label: 'Area'
      pe_area        as PaymentEngineArea,
      @EndUserText.label: 'Object type'
      object_type   as ObjectType,
      @EndUserText.label: 'Object'
      object_key    as ObjectKey,
      @EndUserText.label: 'Group'
      group1        as Group1,
      @EndUserText.label: 'Sub-group'
      group2        as Group2,
      @EndUserText.label: 'Rule'
      rule_id       as RuleId,
      @EndUserText.label: 'Check'
      check_code    as CheckCode,
      @EndUserText.label: 'Severity'
      severity      as Severity,
      @EndUserText.label: 'Action'
      action        as ActionCode,
      @EndUserText.label: 'Amount'
      amount        as Amount,
      @EndUserText.label: 'Currency'
      currency      as Currency,
      @EndUserText.label: 'Reference'
      reference     as Reference,
      @EndUserText.label: 'Message'
      message       as Message,
      @EndUserText.label: 'Disposition'
      disposition   as Disposition,
      @EndUserText.label: 'Owner'
      owner         as Owner,
      @EndUserText.label: 'Due date'
      due_date      as DueDate,
      @EndUserText.label: 'Resolved by'
      resolved_by   as ResolvedBy,
      @EndUserText.label: 'Resolved at'
      resolved_at   as ResolvedAt,
      @EndUserText.label: 'Resolution'
      resolution    as Resolution,
      @EndUserText.label: 'First seen'
      first_seen_at as FirstSeenAt,
      @EndUserText.label: 'Occurrences'
      occurrences   as Occurrences,
      @EndUserText.label: 'Waived until'
      waiver_until  as WaiverUntil,
      @EndUserText.label: 'Waiver requested by'
      waiver_req_by as WaiverReqBy,
      @EndUserText.label: 'Waiver requested at'
      waiver_req_at as WaiverReqAt,
      @EndUserText.label: 'Waiver reason'
      waiver_reason as WaiverReason,
      @EndUserText.label: 'Created at'
      created_at    as CreatedAt,
      _History
}
where
  (
       severity    = 'B'
    or severity    = 'E'
    or severity    = 'W'
  )
  and  disposition <> 'S'
  and  disposition <> 'I'

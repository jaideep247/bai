@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Owned exceptions'
@Metadata.ignorePropagatedAnnotations: true
// Exceptions app (design 6.1): findings of rank >= 2 (B, E, W) that are not superseded
// 2026-11-11 (operations response features): planned downtime mark, correlation group and role, the parent and
// the correlated children of a group (same view: their own DCL rule applies to every row shown), the open
// children of a parent, the runbook link of the check (ZI_CA_OpsFindRunbook)
// 2026-11-11 (explainable, versioned results): configuration rule and version of the finding; business date and
// event time (pilot metrics)
// VERIFY-ADT: self-associations of the root entity redirected in the projection; IS INITIAL on a RAW element
define root view entity ZR_CA_OpsException
  as select from zca_ops_finding
  composition [0..*] of ZR_CA_OpsExcHist as _History
  association [0..*] to ZR_CA_OpsException  as _CorrChildren on  $projection.CorrelationId = _CorrChildren.CorrelationId
                                                            and _CorrChildren.CorrelationRole = 'C'
  association [0..1] to ZR_CA_OpsException  as _CorrParent   on  $projection.CorrelationId = _CorrParent.CorrelationId
                                                            and _CorrParent.CorrelationRole = 'P'
  association [0..1] to ZI_CA_OpsCorrCount  as _CorrCount    on  $projection.CorrelationId = _CorrCount.CorrelationId
  association [0..1] to ZI_CA_OpsFindRunbook as _Runbook     on  $projection.RunId     = _Runbook.RunId
                                                            and $projection.FindingNo = _Runbook.FindingNo
{
      @EndUserText.label: 'Run'
  key run_id        as RunId,
      @EndUserText.label: 'Finding'
  key finding_no    as FindingNo,
      @EndUserText.label: 'Area'
      area        as Area,
      // Company code of the finding (2026-11-10): blank = not company-specific (area-level)
      @EndUserText.label: 'Company code'
      bukrs         as CompanyCode,
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
      // Classification by operations (action classifyException, parameter EXC_REASON_CODES; 2026-11-10)
      @EndUserText.label: 'Reason code'
      reason_code   as ReasonCode,
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
      // ETag (2026-11-10): set by every write - the store, the exception repository and the actions
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      @EndUserText.label: 'Changed at'
      last_changed_at as LastChangedAt,
      // Planned downtime window that covered the finding when recorded (alert held back; blank = none)
      @EndUserText.label: 'Planned downtime window'
      downtime_id   as DowntimeId,
      @EndUserText.label: 'In planned downtime'
      cast( case when downtime_id is initial then ' ' else 'X' end as abap_boolean ) as IsPlannedDowntime,
      // Correlation group and role: P parent (alerted with its children's count), C child (not alerted alone)
      @EndUserText.label: 'Correlation group'
      corr_id       as CorrelationId,
      @EndUserText.label: 'Correlation role'
      corr_role     as CorrelationRole,
      // Explainable, versioned results (2026-11-11): the check (GROUP2) and rule (RULE_ID) are above; the
      // configuration row inside the check and the configuration version of the run that produced the finding
      @EndUserText.label: 'Configuration rule'
      cfg_rule      as ConfigRule,
      @EndUserText.label: 'Configuration version'
      cfg_version   as ConfigVersion,
      @EndUserText.label: 'Version (short)'
      cast( substring( cfg_version, 1, 8 ) as abap.char( 8 ) ) as ConfigVersionShort,
      // Pilot metrics (2026-11-11): business date and event time the finding is about
      @EndUserText.label: 'Business date'
      bus_date      as BusinessDate,
      @EndUserText.label: 'Event time'
      event_at      as EventAt,
      _History,
      _CorrChildren,
      _CorrParent,
      _CorrCount,
      _Runbook
}
where
  (
       severity    = 'B'
    or severity    = 'E'
    or severity    = 'W'
  )
  and  disposition <> 'S'
  and  disposition <> 'I'

// Artifact: zr_ca_opsdowntime.ddls.asddls
// Purpose: Planned downtime windows (RAP BO, root; table ZCA_OPS_DTWIN): area, optional scope patterns (check
//          code, object key, interface or bank), start and end as entered (local date and time in the window's
//          own time zone, parameter DOWNTIME_TIME_ZONE at creation) and in UTC (set on save), reason, planner,
//          four-eyes approver. The status is derived, never stored: Ended once the end has passed (also after
//          End now), else Awaiting approval without approver, Active from the start, Scheduled before it - a
//          window ends by itself. Only approved windows take effect (store mark, alert router, downtime API).
// Modification log: 2026-11-11 | Initial version (operations response features: planned downtime).
// VERIFY-ADT: managed BO over a table with calculated read-only elements (status, criticality) and
//             tstmp_seconds_between over the TIMESTAMPL cast (as ZR_CA_OpsCheckStatus, V51).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Planned downtime windows'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #S, dataClass: #TRANSACTIONAL }
define root view entity ZR_CA_OpsDowntime
  as select from zca_ops_dtwin
  association [0..*] to ZI_CA_OpsDtwStatusT as _StatusText on $projection.WindowStatus = _StatusText.WindowStatus
{
      @EndUserText.label: 'Window'
  key window_id                                             as WindowId,
      @EndUserText.label: 'Area'
      area                                                  as Area,
      @EndUserText.label: 'Check code pattern (PCRE)'
      check_pattern                                         as CheckPattern,
      @EndUserText.label: 'Object key pattern (PCRE)'
      object_pattern                                        as ObjectPattern,
      @EndUserText.label: 'Interface or bank pattern (PCRE)'
      group_pattern                                         as GroupPattern,
      @EndUserText.label: 'From (date)'
      from_date                                             as FromDate,
      @EndUserText.label: 'From (time)'
      from_time                                             as FromTime,
      @EndUserText.label: 'To (date)'
      to_date                                               as ToDate,
      @EndUserText.label: 'To (time)'
      to_time                                               as ToTime,
      @EndUserText.label: 'Time zone'
      time_zone                                             as TimeZone,
      @EndUserText.label: 'From (UTC)'
      from_utc                                              as FromUtc,
      @EndUserText.label: 'To (UTC)'
      to_utc                                                as ToUtc,
      @EndUserText.label: 'Reason'
      reason                                                as Reason,
      @Semantics.user.createdBy: true
      @EndUserText.label: 'Planned by'
      created_by                                            as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      @EndUserText.label: 'Planned at'
      created_at                                            as CreatedAt,
      @EndUserText.label: 'Approved by'
      approved_by                                           as ApprovedBy,
      @EndUserText.label: 'Approved at'
      approved_at                                           as ApprovedAt,
      @EndUserText.label: 'Ended early by'
      ended_by                                              as EndedBy,
      @Semantics.user.lastChangedBy: true
      last_changed_by                                       as LastChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at                                       as LastChangedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at                                 as LocalLastChangedAt,
      // Derived status (ZCL_CA_OPS_DOWNTIME_POLICY=>STATUS, same rule): E ended, P awaiting approval,
      // A active, S scheduled
      @ObjectModel.text.association: '_StatusText'
      @EndUserText.label: 'Status'
      cast( case
              when tstmp_seconds_between( tstmp_current_utctimestamp( ), cast( to_utc as timestamp ), 'NULL' ) <= 0
                then 'E'
              when approved_by = ' '
                then 'P'
              when tstmp_seconds_between( tstmp_current_utctimestamp( ), cast( from_utc as timestamp ), 'NULL' ) <= 0
                then 'A'
              else 'S' end as zca_ops_dtw_status )        as WindowStatus,
      cast( case
              when tstmp_seconds_between( tstmp_current_utctimestamp( ), cast( to_utc as timestamp ), 'NULL' ) <= 0
                then 0
              when approved_by = ' '
                then 2
              when tstmp_seconds_between( tstmp_current_utctimestamp( ), cast( from_utc as timestamp ), 'NULL' ) <= 0
                then 1
              else 3 end as abap.int1 )                     as StatusCriticality,
      _StatusText
}

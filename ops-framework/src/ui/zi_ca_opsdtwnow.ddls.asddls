// Artifact: zi_ca_opsdtwnow.ddls.asddls
// Purpose: Planned downtime windows as of now (ZCA_OPS_DTWIN): approved, active now (start passed, end not), area-
//          wide (no scope pattern), seconds until start and end (negative = passed). The rule of
//          ZCL_CA_OPS_DOWNTIME_POLICY=>IN_EFFECT and =>AREA_WIDE, read live: the area dashboard and the shift
//          handover select from it. Read-only.
// Modification log: 2026-11-11 | Initial version (operations response features: planned downtime).
// VERIFY-ADT: tstmp_seconds_between over the TIMESTAMPL cast and tstmp_current_utctimestamp (V51).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Planned downtime windows as of now'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #S, dataClass: #TRANSACTIONAL }
define view entity ZI_CA_OpsDtwNow
  as select from zca_ops_dtwin
{
  key window_id                                             as WindowId,
      area                                                  as Area,
      from_utc                                              as FromUtc,
      to_utc                                                as ToUtc,
      reason                                                as Reason,
      cast( case when approved_by = ' ' then ' ' else 'X' end as abap_boolean ) as IsApproved,
      cast( case when check_pattern = ' ' and object_pattern = ' ' and group_pattern = ' '
                 then 'X' else ' ' end as abap_boolean )    as IsAreaWide,
      tstmp_seconds_between( tstmp_current_utctimestamp( ), cast( from_utc as timestamp ), 'NULL' ) as StartsInSeconds,
      tstmp_seconds_between( tstmp_current_utctimestamp( ), cast( to_utc as timestamp ), 'NULL' )   as EndsInSeconds,
      cast( case when approved_by <> ' '
                  and tstmp_seconds_between( tstmp_current_utctimestamp( ), cast( from_utc as timestamp ), 'NULL' ) <= 0
                  and tstmp_seconds_between( tstmp_current_utctimestamp( ), cast( to_utc as timestamp ), 'NULL' ) > 0
                 then 'X' else ' ' end as abap_boolean )    as IsActive
}

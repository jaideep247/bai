// Artifact: zi_ca_opsctlrunday.ddls.asddls
// Purpose: Runs of the review window (33 days, test mode left out) with their business date: the start of
//          the run (UTC) as a local date of CONTROL_TIME_ZONE. The start restricts ZCA_OPS_RUN first (index
//          MOD: AREA, STARTED_AT - the area comes from the covered checks), so a business-date filter reads
//          the runs of a few days, never the 400 days of history. Read-only.
// Modification log: 2026-11-10 | Initial version (control register and daily control review).
// VERIFY-ADT: comparison of TIMESTAMPL with the cast of tstmp_add_seconds; PlanViz: the BusinessDate
//             filter of a card is applied to these rows before the findings are joined (CTL-08).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Control review: runs per business date'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #M, dataClass: #TRANSACTIONAL }
define view entity ZI_CA_OpsCtlRunDay
  as select from zca_ops_run    as Run
    inner join   ZI_CA_OpsCtlTz as Tz on Tz.Language = $session.system_language
{
  key Run.run_id                                            as RunId,
      Run.area                                              as Area,
      Run.started_at                                        as StartedAt,
      tstmp_to_dats( cast( Run.started_at as timestamp ), Tz.TimeZone, $session.client, 'NULL' ) as BusinessDate
}
where
      Run.test_mode  =  ' '
  and Run.started_at >= cast( tstmp_add_seconds( tstmp_current_utctimestamp(),
                                                 cast( -2851200 as abap.dec( 15, 0 ) ), 'INITIAL' )
                              as abap.dec( 21, 7 ) )

// Artifact: zi_ca_opsbusday.ddls.asddls
// Purpose: Business dates of the daily control review: every calendar day of the last 31 days up to today,
//          today being the local date of the time zone CONTROL_TIME_ZONE (ZI_CA_OpsCtlTz), with the local
//          time now (review cut-off) and the flag of the current business date. A date dimension, so a
//          control is listed (and awaits review) also on a day its checks raised nothing. Read-only.
// Modification log: 2026-11-10 | Initial version (control register and daily control review).
// VERIFY-ADT: I_CalendarDate filled for the years in use (SCAL_TT_DATE); tstmp_to_dats / tstmp_to_tims with
//             a time zone element; fallback: days of ZCA_OPS_RUN (a day without any run is not listed).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Control review: business dates'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #A, sizeCategory: #S, dataClass: #MASTER }
define view entity ZI_CA_OpsBusDay
  as select from I_CalendarDate as Cal
    inner join   ZI_CA_OpsCtlTz as Tz on Tz.Language = $session.system_language
{
  key Cal.CalendarDate                                      as BusinessDate,
      Tz.TimeZone,
      tstmp_to_dats( tstmp_current_utctimestamp(), Tz.TimeZone, $session.client, 'NULL' ) as Today,
      tstmp_to_tims( tstmp_current_utctimestamp(), Tz.TimeZone, $session.client, 'NULL' ) as NowTime,
      cast( case when Cal.CalendarDate = tstmp_to_dats( tstmp_current_utctimestamp(), Tz.TimeZone,
                                                         $session.client, 'NULL' )
                 then 'X' else ' ' end as abap_boolean )    as IsCurrentDay
}
where
      Cal.CalendarDate >= dats_add_days( $session.system_date, -32, 'INITIAL' )
  and Cal.CalendarDate <= tstmp_to_dats( tstmp_current_utctimestamp(), Tz.TimeZone, $session.client, 'NULL' )

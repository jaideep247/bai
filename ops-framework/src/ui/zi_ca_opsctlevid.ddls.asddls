// Artifact: zi_ca_opsctlevid.ddls.asddls
// Purpose: Evidence of a control on a business date: the latest run of the control's areas on that date
//          (run ID, its area and start) - shown in the review app and stored with a sign-off, never typed.
//          MAX( RunId ) only decides between runs of two areas that started at the same instant. Read-only.
// Modification log: 2026-11-10 | Initial version (control register and daily control review).
// VERIFY-ADT: MAX on a RAW 16 element (7.58); fallback: RunId as a key element (one row per run).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Control review: evidence run per date'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #M, dataClass: #TRANSACTIONAL }
define view entity ZI_CA_OpsCtlEvid
  as select from ZI_CA_OpsCtlRunMax as Last
    inner join   ZI_CA_OpsCtlArea   as Ctl on  Ctl.Area      = Last.Area
                                           and Ctl.ControlId = Last.ControlId
    inner join   ZI_CA_OpsCtlRunDay as Run on  Run.Area      = Ctl.CheckArea
                                           and Run.StartedAt = Last.LastRunAt
{
  key Last.Area,
  key Last.ControlId,
  key Last.BusinessDate,
      max( Run.RunId )                                      as EvidenceRun,
      max( Last.LastRunAt )                                 as EvidenceRunAt
}
group by
  Last.Area,
  Last.ControlId,
  Last.BusinessDate

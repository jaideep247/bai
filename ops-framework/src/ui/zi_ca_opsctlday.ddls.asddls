// Artifact: zi_ca_opsctlday.ddls.asddls
// Purpose: One row per active control (ZCA_OPS_CONTROL) and business date of the review window
//          (ZI_CA_OpsBusDay) with what the review needs, all read live: the status rank of the date's
//          findings (ZI_CA_OpsCtlFindDay, 0 when none), open exceptions now (ZI_CA_OpsCtlOpen), the
//          evidence run (ZI_CA_OpsCtlEvid), the guidance in the logon language (else the original language
//          E) and the sign-off of the date (ZCA_OPS_REVIEW) with the rank of its status. The flags are
//          ZI_CA_OpsCtlState. Read-only.
// Modification log: 2026-11-10 | Initial version (control register and daily control review).
// VERIFY-ADT: CROSS JOIN in a CDS view entity (7.58); fallback: inner join on Day.BusinessDate >= '00000000'.
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Control review: control per business date'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #M, dataClass: #MIXED }
define view entity ZI_CA_OpsCtlDay
  as select from    zca_ops_control     as Ctl
    cross join      ZI_CA_OpsBusDay     as Day
    left outer join ZI_CA_OpsCtlFindDay as Fd   on  Fd.Area         = Ctl.area
                                                and Fd.ControlId    = Ctl.control_id
                                                and Fd.BusinessDate = Day.BusinessDate
    left outer join ZI_CA_OpsCtlOpen    as Op   on  Op.Area      = Ctl.area
                                                and Op.ControlId = Ctl.control_id
    left outer join ZI_CA_OpsCtlEvid    as Ev   on  Ev.Area         = Ctl.area
                                                and Ev.ControlId    = Ctl.control_id
                                                and Ev.BusinessDate = Day.BusinessDate
    left outer join zca_ops_ctlt        as Txt  on  Txt.langu      = $session.system_language
                                                and Txt.area       = Ctl.area
                                                and Txt.control_id = Ctl.control_id
    left outer join zca_ops_ctlt        as TxtE on  TxtE.langu      = 'E'
                                                and TxtE.area       = Ctl.area
                                                and TxtE.control_id = Ctl.control_id
    left outer join zca_ops_review      as Rev  on  Rev.area          = Ctl.area
                                                and Rev.control_id    = Ctl.control_id
                                                and Rev.business_date = Day.BusinessDate
{
  key Ctl.area                                              as Area,
  key Ctl.control_id                                        as ControlId,
  key Day.BusinessDate,
      Ctl.description                                       as ControlName,
      Ctl.category                                          as Category,
      Ctl.owner                                             as Owner,
      Ctl.backup                                            as Backup,
      Ctl.team                                              as Team,
      Ctl.cutoff_time                                       as CutoffTime,
      Ctl.runbook_url                                       as RunbookUrl,
      Ctl.seq                                               as Sequence,
      cast( coalesce( Txt.guidance, TxtE.guidance ) as abap.char( 255 ) ) as Guidance,
      Day.TimeZone,
      Day.Today,
      Day.NowTime,
      Day.IsCurrentDay,
      cast( coalesce( Fd.StatusRank, 0 ) as abap.int4 )     as StatusRank,
      cast( coalesce( Fd.FindingCount, 0 ) as abap.int4 )   as FindingCount,
      Fd.LastFindingAt,
      cast( coalesce( Op.OpenExceptions, 0 ) as abap.int4 ) as OpenExceptions,
      Ev.EvidenceRun,
      Ev.EvidenceRunAt,
      Rev.status_at_review                                  as StatusAtReview,
      cast( case Rev.status_at_review when 'A' then 2
                                      when 'W' then 1
                                      else 0 end as abap.int4 ) as ReviewRank,
      Rev.review_result                                     as ReviewResult,
      Rev.evidence_run                                      as ReviewedEvidenceRun,
      Rev.reviewed_by                                       as ReviewedBy,
      Rev.reviewed_at                                       as ReviewedAt,
      Rev.observation                                       as Observation,
      Rev.next_action                                       as NextAction,
      Rev.last_changed_at                                   as LastChangedAt
}
where
  Ctl.active = 'X'

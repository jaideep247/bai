// Artifact: zi_ca_opsctlday.ddls.asddls
// Purpose: One row per slice of the review - active control (ZCA_OPS_CONTROL), business date of the review
//          window (ZI_CA_OpsBusDay) and company code (ZI_CA_OpsCtlSlice: blank = area-level) - with what the
//          review needs, all read live: the status rank of the date's
//          findings (ZI_CA_OpsCtlFindDay, 0 when none), open exceptions now (ZI_CA_OpsCtlOpen), the
//          evidence run (ZI_CA_OpsCtlEvid), the guidance in the logon language (else the original language
//          E) and the sign-off of the date (ZCA_OPS_REVIEW) with the rank of its status. The flags are
//          ZI_CA_OpsCtlState. Read-only.
// Modification log: 2026-11-10 | Initial version (control register and daily control review).
//                   2026-11-10 | Company-code isolation: rows per slice (ZI_CA_OpsCtlSlice); status, findings,
//                                open exceptions and sign-off of the slice's company code only; the evidence run
//                                (area-level: a run has no company code) on every slice of the date.
// VERIFY-ADT: CROSS JOIN in a CDS view entity (7.58); fallback: inner join on Day.BusinessDate >= '00000000'.
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Control review: control per business date'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #M, dataClass: #MIXED }
define view entity ZI_CA_OpsCtlDay
  as select from    ZI_CA_OpsCtlSlice   as Sl
    inner join      zca_ops_control     as Ctl  on  Ctl.area       = Sl.Area
                                                and Ctl.control_id = Sl.ControlId
    inner join      ZI_CA_OpsBusDay     as Day  on  Day.BusinessDate = Sl.BusinessDate
    left outer join ZI_CA_OpsCtlFindDay as Fd   on  Fd.Area         = Sl.Area
                                                and Fd.ControlId    = Sl.ControlId
                                                and Fd.BusinessDate = Sl.BusinessDate
                                                and Fd.CompanyCode  = Sl.CompanyCode
    left outer join ZI_CA_OpsCtlOpen    as Op   on  Op.Area        = Sl.Area
                                                and Op.ControlId   = Sl.ControlId
                                                and Op.CompanyCode = Sl.CompanyCode
    left outer join ZI_CA_OpsCtlEvid    as Ev   on  Ev.Area         = Sl.Area
                                                and Ev.ControlId    = Sl.ControlId
                                                and Ev.BusinessDate = Sl.BusinessDate
    left outer join zca_ops_ctlt        as Txt  on  Txt.langu      = $session.system_language
                                                and Txt.area       = Ctl.area
                                                and Txt.control_id = Ctl.control_id
    left outer join zca_ops_ctlt        as TxtE on  TxtE.langu      = 'E'
                                                and TxtE.area       = Ctl.area
                                                and TxtE.control_id = Ctl.control_id
    left outer join zca_ops_review      as Rev  on  Rev.area          = Sl.Area
                                                and Rev.control_id    = Sl.ControlId
                                                and Rev.business_date = Sl.BusinessDate
                                                and Rev.bukrs         = Sl.CompanyCode
{
  key Sl.Area,
  key Sl.ControlId,
  key Sl.BusinessDate,
  key Sl.CompanyCode,
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

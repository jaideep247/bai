// Artifact: zr_ca_opspfmilestone.ddls.asddls
// Purpose: Payment file lifecycle - stage timeline of a file (ZCA_OPS_PFMST, one row per configured milestone in the
//          product order: payment run, SAP generation, middleware pickup, onward delivery, bank receipt, bank
//          acceptance, posting / settlement): status (reached, late, implied, pending, missing, rejected, partial,
//          failed, unknown), deadline, when it was observed, minutes late and the evidence row that decided it, with
//          a criticality for the timeline. The company code is the file's (DCL). Read-only.
// Modification log: 2026-11-15 | Initial version (build K: payment file lifecycle).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment file stage timeline'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define root view entity ZR_CA_OpsPfMilestone
  as select from zca_ops_pfmst  as Mst
    inner join   zca_ops_pffile as Fil on  Fil.area    = Mst.area
                                       and Fil.file_id = Mst.file_id
{
  key Mst.area                                              as Area,
  key Mst.file_id                                           as FileId,
  key Mst.milestone                                         as Milestone,
      Fil.bukrs                                             as CompanyCode,
      Mst.seq                                               as Sequence,
      Mst.required                                          as IsRequired,
      Mst.status                                            as Status,
      cast( case Mst.status when 'REACHED' then 3 when 'IMPLIED' then 3 when 'PENDING' then 0 when 'UNKNOWN' then 0
                            when 'LATE' then 2 else 1 end as abap.int1 ) as StatusCriticality,
      Mst.outcome                                           as Outcome,
      Mst.due_at                                            as DueAt,
      Mst.observed_at                                       as ObservedAt,
      Mst.late_min                                          as LateMinutes,
      Mst.event_key                                         as EventKey,
      Mst.evaluated_at                                      as EvaluatedAt
}

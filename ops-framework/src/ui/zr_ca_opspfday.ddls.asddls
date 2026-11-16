// Artifact: zr_ca_opspfday.ddls.asddls
// Purpose: Payment file lifecycle - expected versus observed per file type and business date (ZCA_OPS_PFDAY): day kind
//          (business day / holiday of the calendar), files expected and observed, result (OK, valid zero-volume day,
//          holiday, stale source, not evaluated, pending, missing, partial) with its reason, the file source's
//          freshness and watermark at the evaluation, completeness and the last valid result. Area-level (no company
//          code). Read-only.
// Modification log: 2026-11-15 | Initial version (build K: payment file lifecycle).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment files expected per day'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #M, dataClass: #TRANSACTIONAL }
define root view entity ZR_CA_OpsPfDay
  as select from zca_ops_pfday as Day
{
  key Day.area                                              as Area,
  key Day.file_type                                         as FileType,
  key Day.bus_date                                          as BusinessDate,
      Day.day_kind                                          as DayKind,
      Day.expected                                          as Expected,
      Day.observed                                          as Observed,
      Day.result                                            as Result,
      cast( case Day.result when 'OK' then 3 when 'ZERO_OK' then 3 when 'HOLIDAY' then 0 when 'PENDING' then 0
                            when 'STALE' then 2 when 'NOT_EVAL' then 2 else 1 end as abap.int1 ) as ResultCriticality,
      Day.reason                                            as Reason,
      Day.as_of                                             as SourceAsOf,
      Day.watermark                                         as Watermark,
      Day.completeness                                      as Completeness,
      Day.eval_at                                           as EvaluatedAt,
      Day.last_valid_result                                 as LastValidResult,
      Day.last_valid_at                                     as LastValidAt
}

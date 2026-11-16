// Artifact: zr_ca_opscoverage.ddls.asddls
// Purpose: Monitor coverage per area and licence module (build O, docs/EVALUATION_AND_COVERAGE.md section 5): one
//          row per registered check (active or not) with its business process, catalogue process and licence module
//          (the generated module map ZCA_OPS_LICMOD: the check class's module, else the catalogue process's, else
//          CORE) and its coverage state - DISABLED (check or business process switched off by configuration),
//          REFUSED (the latest run recorded the licence refusing a module, LIC_ENFORCE = X), NOT_RUN (expected but no
//          evaluation within its schedule window - a monitor gap, never silence), IMPAIRED (latest evaluation not
//          evaluated, stale or partial), WARNED (ran under a licence warning, LIC_ENFORCE = W), RAN - the rule of
//          ZCL_CA_OPS_COVERAGE on the stored records. The licence state is the one the runner read through the
//          licence service at the run (ZCA_OPS_EVAL-LIC_STATE); the coverage check reads it live. Counters for the
//          coverage card (per area and module). Nothing stored, read-only (no behaviour definition).
// Modification log: 2026-11-16 | Initial version (build O: monitor coverage state).
// VERIFY-ADT (V277): nested coalesce over two left outer joins of the same table with literals in the ON condition.
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Monitor coverage per check'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #M, dataClass: #MIXED }
define root view entity ZR_CA_OpsCoverage
  as select from    zca_ops_check    as Chk
    inner join      ZI_CA_OpsEvalNow as En  on  En.Area    = Chk.area
                                            and En.CheckId = Chk.check_id
    left outer join ZI_CA_OpsChkEff  as Eff on  Eff.Area    = Chk.area
                                            and Eff.CheckId = Chk.check_id
    left outer join zca_ops_proc     as Proc on  Proc.area       = Chk.area
                                             and Proc.process_id = Chk.process_id
    left outer join zca_ops_licmod   as LmC on  LmC.obj_kind = 'CLAS'
                                            and LmC.obj_name = Chk.class_name
    left outer join zca_ops_licmod   as LmP on  LmP.obj_kind = 'PRC'
                                            and LmP.obj_name = Proc.cat_process
  association [0..*] to ZI_CA_OpsCovStateT  as _CoverageText on $projection.CoverageState = _CoverageText.CoverageState
  association [0..*] to ZI_CA_OpsEvalStateT as _EvalText     on $projection.EvaluationState = _EvalText.EvaluationState
{
  key Chk.area                                              as Area,
  key Chk.check_id                                          as CheckId,
      Chk.description                                       as CheckName,
      Chk.process_id                                        as ProcessId,
      Proc.cat_process                                      as CatalogueProcess,
      Chk.class_name                                        as ClassName,
      Chk.sched_group                                       as ScheduleGroup,
      cast( coalesce( LmC.module, coalesce( LmP.module, 'CORE' ) ) as abap.char( 20 ) ) as LicenceModule,
      @ObjectModel.text.association: '_CoverageText'
      cast( case
              when Eff.CheckId is null then 'DISABLED'
              when coalesce( En.LicenceState, ' ' ) = 'R' then 'REFUSED'
              when En.IsInWindow <> 'X' then 'NOT_RUN'
              when En.IsUnknown = 'X' then 'IMPAIRED'
              when coalesce( En.LicenceState, ' ' ) = 'W' then 'WARNED'
              else 'RAN' end as zca_ops_cov_state )        as CoverageState,
      cast( case
              when Eff.CheckId is null then 0
              when coalesce( En.LicenceState, ' ' ) = 'R' then 1
              when En.IsInWindow <> 'X' then 1
              when En.IsUnknown = 'X' then 2
              when coalesce( En.LicenceState, ' ' ) = 'W' then 2
              else 3 end as abap.int1 )                     as CoverageCriticality,
      cast( case when Eff.CheckId is null then ' ' else 'X' end as abap_boolean ) as IsExpected,
      @ObjectModel.text.association: '_EvalText'
      En.EvaluationState                                    as EvaluationState,
      En.EvaluationCriticality                              as EvaluationCriticality,
      En.EvaluatedAt                                        as EvaluatedAt,
      En.WindowMinutes                                      as WindowMinutes,
      En.Reason                                             as EvaluationReason,
      En.LicenceState                                       as LicenceState,
      // Counters of the coverage card (sum over the checks the user may read)
      cast( 1 as abap.int4 )                                as CheckCount,
      cast( case when Eff.CheckId is null then 0 else 1 end as abap.int4 ) as ExpectedCount,
      cast( case when Eff.CheckId is not null and coalesce( En.LicenceState, ' ' ) <> 'R' and En.IsInWindow = 'X'
                  and En.IsUnknown <> 'X' then 1 else 0 end as abap.int4 ) as RanCount,
      cast( case when Eff.CheckId is not null and coalesce( En.LicenceState, ' ' ) <> 'R' and En.IsInWindow = 'X'
                  and En.IsUnknown = 'X' then 1 else 0 end as abap.int4 ) as ImpairedCount,
      cast( case when Eff.CheckId is not null and coalesce( En.LicenceState, ' ' ) <> 'R' and En.IsInWindow <> 'X'
                 then 1 else 0 end as abap.int4 )           as NotRunCount,
      cast( case when Eff.CheckId is null then 1 else 0 end as abap.int4 ) as DisabledCount,
      cast( case when Eff.CheckId is not null and coalesce( En.LicenceState, ' ' ) = 'R' then 1 else 0 end as abap.int4 ) as RefusedCount,
      cast( case when Eff.CheckId is not null and coalesce( En.LicenceState, ' ' ) = 'W' then 1 else 0 end as abap.int4 ) as WarnedCount,
      // A monitor gap: expected and refused, not run or impaired
      cast( case when Eff.CheckId is not null
                  and ( coalesce( En.LicenceState, ' ' ) = 'R' or En.IsInWindow <> 'X' or En.IsUnknown = 'X' )
                 then 1 else 0 end as abap.int4 )           as GapCount,
      _CoverageText,
      _EvalText
}

// Artifact: zi_ca_opscatrun.ddls.asddls
// Purpose: Catalogue milestone "runnable check" (build O, docs/EVALUATION_AND_COVERAGE.md section 6): the registered
//          checks (ZCA_OPS_CHECK, active or not - a delivered inactive monitoring row is runnable) with a check
//          class of the business processes that monitor a catalogue process (ZCA_OPS_PROC-CAT_PROCESS), counted -
//          a no-code aggregate check is registered with its class ZCL_CA_OPS_CHK_AGG. Nothing stored, read-only.
// Modification log: 2026-11-16 | Initial version (build O: catalogue milestones).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Catalogue: runnable checks of a process'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #A, sizeCategory: #S, dataClass: #CUSTOMIZING }
define view entity ZI_CA_OpsCatRun
  as select from zca_ops_proc  as Proc
    inner join   zca_ops_check as Chk on  Chk.area       = Proc.area
                                      and Chk.process_id = Proc.process_id
{
  key Proc.cat_process                                      as ProcessId,
      cast( count( * ) as abap.int4 )                       as RunnableChecks
}
where
      Proc.cat_process <> ' '
  and Chk.class_name   <> ' '
group by
  Proc.cat_process

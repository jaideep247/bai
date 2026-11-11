// Artifact: zc_ca_opsjobstep.ddls.asddls
// Purpose: Steps of a kept job (ZCA_OPS_JOBSTEP: program, variant, step user, spool list) for the object page of the
//          SAP job failures board (service ZUI_CA_OPS_JOBS), with the area and company code of the job for the read
//          authorisation (DCL ZC_CA_OPSJOBFAILURE). Read-only.
// Modification log: 2026-11-11 | Initial version (SAP job monitor).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'SAP job failures: steps'
@Metadata.allowExtensions: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define view entity ZC_CA_OpsJobStep
  as select from zca_ops_jobstep as Step
    inner join   zca_ops_job     as Job on  Job.jobname  = Step.jobname
                                        and Job.jobcount = Step.jobcount
{
  key Step.jobname   as JobName,
  key Step.jobcount  as JobCount,
  key Step.stepcount as StepCount,
      Step.progname  as ProgramName,
      Step.variant   as Variant,
      Step.step_user as StepUser,
      Step.spool_id  as SpoolId,
      Job.area       as Area,
      Job.bukrs      as CompanyCode
}

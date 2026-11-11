// Artifact: zc_ca_opsjobalog.ddls.asddls
// Purpose: Application logs linked to a failed job (ZCA_OPS_JOBALOG: BALHDR log number, object / subobject,
//          external number, error and abort counters, evidence quality) for the object page of the SAP job failures
//          board (service ZUI_CA_OPS_JOBS); open the log in SLG1 with the log number. Area and company code of the
//          job for the read authorisation (DCL ZC_CA_OPSJOBFAILURE). Read-only.
// Modification log: 2026-11-11 | Initial version (SAP job monitor).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'SAP job failures: application logs'
@Metadata.allowExtensions: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define view entity ZC_CA_OpsJobAlog
  as select from zca_ops_jobalog as Alog
    inner join   zca_ops_job     as Job on  Job.jobname  = Alog.jobname
                                        and Job.jobcount = Alog.jobcount
{
  key Alog.jobname   as JobName,
  key Alog.jobcount  as JobCount,
  key Alog.lognumber as LogNumber,
      Alog.object    as LogObject,
      Alog.subobject as LogSubobject,
      Alog.extnumber as ExternalNumber,
      Alog.log_date  as LogDate,
      Alog.log_time  as LogTime,
      Alog.log_user  as LogUser,
      Alog.log_prog  as LogProgram,
      Alog.msg_cnt_e as ErrorMessages,
      Alog.msg_cnt_a as AbortMessages,
      Alog.quality   as Quality,
      Job.area       as Area,
      Job.bukrs      as CompanyCode
}

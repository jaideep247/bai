// Artifact: zc_ca_opsjobmsg.ddls.asddls
// Purpose: Job log error / abort lines kept for a failed job (ZCA_OPS_JOBMSG: message class, number, type, text,
//          time) for the object page of the SAP job failures board (service ZUI_CA_OPS_JOBS), with the area and
//          company code of the job for the read authorisation (DCL ZC_CA_OPSJOBFAILURE). Read-only.
// Modification log: 2026-11-11 | Initial version (SAP job monitor).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'SAP job failures: job log errors'
@Metadata.allowExtensions: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #L, dataClass: #TRANSACTIONAL }
define view entity ZC_CA_OpsJobMsg
  as select from zca_ops_jobmsg as Msg
    inner join   zca_ops_job    as Job on  Job.jobname  = Msg.jobname
                                       and Job.jobcount = Msg.jobcount
{
  key Msg.jobname      as JobName,
  key Msg.jobcount     as JobCount,
  key Msg.line_no      as LineNo,
      Msg.entered_date as EnteredDate,
      Msg.entered_time as EnteredTime,
      Msg.msgid        as MessageClass,
      Msg.msgno        as MessageNumber,
      Msg.msgtype      as MessageType,
      Msg.text         as MessageText,
      Job.area         as Area,
      Job.bukrs        as CompanyCode
}

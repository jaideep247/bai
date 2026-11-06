@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Exception action history'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CD_OpsExcHist
  as select from zcd_ops_exc_hist
  association to parent ZR_CD_OpsException as _Exception on  $projection.RunId     = _Exception.RunId
                                                         and $projection.FindingNo = _Exception.FindingNo
{
      @EndUserText.label: 'History ID'
  key hist_uuid  as HistUuid,
      @EndUserText.label: 'Run'
      run_id     as RunId,
      @EndUserText.label: 'Finding'
      finding_no as FindingNo,
      @EndUserText.label: 'Action'
      action     as HistAction,
      @EndUserText.label: 'From'
      from_disp  as FromDisp,
      @EndUserText.label: 'To'
      to_disp    as ToDisp,
      @EndUserText.label: 'Owner'
      owner      as Owner,
      @EndUserText.label: 'Reason'
      reason     as Reason,
      @EndUserText.label: 'Reference'
      reference  as Reference,
      @EndUserText.label: 'By'
      created_by as CreatedBy,
      @EndUserText.label: 'At'
      created_at as CreatedAt,
      _Exception
}

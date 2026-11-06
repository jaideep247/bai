@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Exception action history'
@Metadata.allowExtensions: true
define view entity ZC_CD_OpsExcHist
  as projection on ZR_CD_OpsExcHist
{
  key HistUuid,
      RunId,
      FindingNo,
      HistAction,
      FromDisp,
      ToDisp,
      Owner,
      Reason,
      Reference,
      CreatedBy,
      CreatedAt,
      _Exception : redirected to parent ZC_CD_OpsException
}

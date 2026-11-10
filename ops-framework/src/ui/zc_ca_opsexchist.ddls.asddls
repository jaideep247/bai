@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Exception action history'
@Metadata.allowExtensions: true
define view entity ZC_CA_OpsExcHist
  as projection on ZR_CA_OpsExcHist
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
      _Exception : redirected to parent ZC_CA_OpsException
}

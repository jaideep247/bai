@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Owned exceptions'
@Metadata.allowExtensions: true
define root view entity ZC_CD_OpsException
  provider contract transactional_query
  as projection on ZR_CD_OpsException
{
  key RunId,
  key FindingNo,
      PaymentEngineArea,
      ObjectType,
      ObjectKey,
      Group1,
      Group2,
      RuleId,
      CheckCode,
      Severity,
      ActionCode,
      Amount,
      Currency,
      Reference,
      Message,
      Disposition,
      Owner,
      DueDate,
      ResolvedBy,
      ResolvedAt,
      Resolution,
      FirstSeenAt,
      Occurrences,
      WaiverUntil,
      WaiverReqBy,
      WaiverReqAt,
      WaiverReason,
      CreatedAt,
      LastChangedAt,
      _History : redirected to composition child ZC_CD_OpsExcHist
}

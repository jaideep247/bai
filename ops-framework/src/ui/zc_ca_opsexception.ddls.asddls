@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Owned exceptions'
@Metadata.allowExtensions: true
define root view entity ZC_CA_OpsException
  provider contract transactional_query
  as projection on ZR_CA_OpsException
{
  key RunId,
  key FindingNo,
      Area,
      CompanyCode,
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
      ReasonCode,
      FirstSeenAt,
      Occurrences,
      WaiverUntil,
      WaiverReqBy,
      WaiverReqAt,
      WaiverReason,
      CreatedAt,
      LastChangedAt,
      _History : redirected to composition child ZC_CA_OpsExcHist
}

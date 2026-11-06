@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Alert rules'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['RuleId']
define view entity ZC_CD_AlertRule
  as projection on ZR_CD_AlertRule
{
  key RuleId,
      @Consumption.hidden: true
      SingletonID,
      PaymentEngineArea,
      MinSeverity,
      RulePattern,
      CheckPattern,
      Group1Pattern,
      Group2Pattern,
      MinRag,
      OnAbort,
      Channel,
      Destination,
      Digest,
      MaxItems,
      ThrottleMin,
      QuietFrom,
      QuietTo,
      EscalateAfter,
      EscalationDest,
      Active,
      ChangedBy,
      ChangedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _OpsCfgAll : redirected to parent ZC_CD_OpsCfgAll
}

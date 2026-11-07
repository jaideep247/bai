@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Role sequence outcomes'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['Flow', 'MethodClass', 'Seq']
define view entity ZC_CD_HckSeqOutcome
  as projection on ZR_CD_HckSeqOutcome
{
  key Flow,
  key MethodClass,
  key Seq,
      @Consumption.hidden: true
      SingletonID,
      SeqPattern,
      Outcome,
      ExpectedDfkkrp,
      MaxAgeDays,
      Severity,
      Description,
      Active,
      ChangedBy,
      ChangedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _HckCfgAll : redirected to parent ZC_CD_HckCfgAll
}

@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Clearing / return evidence rules'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['Flow', 'MethodClass', 'Purpose', 'Seq']
define view entity ZC_CD_HckClrRule
  as projection on ZR_CD_HckClrRule
{
  key Flow,
  key MethodClass,
  key Purpose,
  key Seq,
      @Consumption.hidden: true
      SingletonID,
      EvidenceClass,
      Param1,
      Param2,
      Param3,
      Required,
      Description,
      Active,
      ChangedBy,
      ChangedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _HckCfgAll : redirected to parent ZC_CD_HckCfgAll
}

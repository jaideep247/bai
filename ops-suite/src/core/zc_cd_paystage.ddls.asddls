@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment lifecycle stages'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['Stage']
define view entity ZC_CD_PayStage
  as projection on ZR_CD_PayStage
{
  key Stage,
      @Consumption.hidden: true
      SingletonID,
      Seq,
      Label,
      Source,
      MatchValue,
      Active,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _OpsCfgAll : redirected to parent ZC_CD_OpsCfgAll
}

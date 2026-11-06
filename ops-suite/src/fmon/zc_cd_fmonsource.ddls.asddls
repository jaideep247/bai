@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Source adapters'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['SrcId']
define view entity ZC_CD_FmonSource
  as projection on ZR_CD_FmonSource
{
  key SrcId,
      @Consumption.hidden: true
      SingletonID,
      IfaceId,
      TableName,
      FileKeyField,
      FileNameField,
      DateField,
      TimeField,
      TsField,
      StatusField,
      CountField,
      AmountField,
      SizeField,
      ChecksumField,
      SourceField,
      LobField,
      DefaultStage,
      AdapterClass,
      Active,
      Description,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _FmonCfgAll : redirected to parent ZC_CD_FmonCfgAll
}

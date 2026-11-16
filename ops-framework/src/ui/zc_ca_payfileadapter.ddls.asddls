@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment file adapters'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['Area', 'FileType', 'Role']
define view entity ZC_CA_PayFileAdapter
  as projection on ZR_CA_PayFileAdapter
{
  key Area,
  key FileType,
  key Role,
      @Consumption.hidden: true
      SingletonID,
      SourceId,
      ClassName,
      Setting,
      SourceType,
      Active,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _OpsCfgAll : redirected to parent ZC_CA_OpsCfgAll
}

@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Link registry business objects'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['ObjectId']
define view entity ZC_CA_LinkObject
  as projection on ZR_CA_LinkObject
{
  key ObjectId,
      @Consumption.hidden: true
      SingletonID,
      LayerId,
      SourceName,
      SourceKind,
      KeyFields,
      Description,
      Active,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _OpsCfgAll : redirected to parent ZC_CA_OpsCfgAll
}

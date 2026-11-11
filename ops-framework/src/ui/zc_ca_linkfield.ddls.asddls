@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Link registry object fields'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['ObjectId', 'FieldName']
define view entity ZC_CA_LinkField
  as projection on ZR_CA_LinkField
{
  key ObjectId,
  key FieldName,
      @Consumption.hidden: true
      SingletonID,
      LayerId,
      SourceName,
      DataElement,
      Sensitivity,
      Evidence,
      VerifyRef,
      Description,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _OpsCfgAll : redirected to parent ZC_CA_OpsCfgAll
}

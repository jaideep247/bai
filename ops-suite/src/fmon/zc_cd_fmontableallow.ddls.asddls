@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Approved tables'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['TableName', 'FieldName']
define view entity ZC_CD_FmonTableAllow
  as projection on ZR_CD_FmonTableAllow
{
  key TableName,
  key FieldName,
      @Consumption.hidden: true
      SingletonID,
      Active,
      Description,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _FmonCfgAll : redirected to parent ZC_CD_FmonCfgAll
}

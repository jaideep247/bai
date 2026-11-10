@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Tables approved for aggregate checks'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['Area', 'TableName']
define view entity ZC_CA_ApprovedTable
  as projection on ZR_CA_ApprovedTable
{
  key Area,
  key TableName,
      @Consumption.hidden: true
      SingletonID,
      Active,
      ApprovedBy,
      Description,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _OpsCfgAll : redirected to parent ZC_CA_OpsCfgAll
}

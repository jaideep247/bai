@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Approved tables per reader'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['PaymentEngineArea', 'Purpose', 'TableName', 'FieldName']
define view entity ZC_CD_ApprovedTable
  as projection on ZR_CD_ApprovedTable
{
  key PaymentEngineArea,
  key Purpose,
  key TableName,
  key FieldName,
      @Consumption.hidden: true
      SingletonID,
      Active,
      ApprovedBy,
      Description,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _OpsCfgAll : redirected to parent ZC_CD_OpsCfgAll
}

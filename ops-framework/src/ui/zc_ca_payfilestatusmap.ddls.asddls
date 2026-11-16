@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment file status mapping'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['Area', 'SourceId', 'Status']
define view entity ZC_CA_PayFileStatusMap
  as projection on ZR_CA_PayFileStatusMap
{
  key Area,
  key SourceId,
  key Status,
      @Consumption.hidden: true
      SingletonID,
      Milestone,
      Outcome,
      Description,
      Active,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _OpsCfgAll : redirected to parent ZC_CA_OpsCfgAll
}

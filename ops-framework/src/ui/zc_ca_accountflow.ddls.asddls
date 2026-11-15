@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Account flows'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['Area', 'FlowId']
define view entity ZC_CA_AccountFlow
  as projection on ZR_CA_AccountFlow
{
  key Area,
  key FlowId,
      @Consumption.hidden: true
      SingletonID,
      Description,
      Direction,
      JrnlLedger,
      ProcessId,
      Active,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _OpsCfgAll : redirected to parent ZC_CA_OpsCfgAll
}

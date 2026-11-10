@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Controls (daily review)'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['Area', 'ControlId']
define view entity ZC_CA_Control
  as projection on ZR_CA_Control
{
  key Area,
  key ControlId,
      @Consumption.hidden: true
      SingletonID,
      Description,
      Category,
      Owner,
      Backup,
      Team,
      CutoffTime,
      RunbookUrl,
      Active,
      Seq,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _OpsCfgAll : redirected to parent ZC_CA_OpsCfgAll
}

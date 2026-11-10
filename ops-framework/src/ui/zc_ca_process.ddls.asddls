@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Business processes'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['Area', 'ProcessId']
define view entity ZC_CA_Process
  as projection on ZR_CA_Process
{
  key Area,
  key ProcessId,
      @Consumption.hidden: true
      SingletonID,
      Description,
      Owner,
      Backup,
      RunbookUrl,
      AuthRole,
      OwnData,
      PurgeTarget,
      Active,
      Seq,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _OpsCfgAll : redirected to parent ZC_CA_OpsCfgAll
}

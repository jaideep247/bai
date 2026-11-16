@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment file types'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['Area', 'FileType']
define view entity ZC_CA_PayFileType
  as projection on ZR_CA_PayFileType
{
  key Area,
  key FileType,
      @Consumption.hidden: true
      SingletonID,
      Description,
      ProcessId,
      Direction,
      AckLevel,
      AckMulti,
      CalendarId,
      TimeZone,
      DayCutoff,
      ExpectedFiles,
      ZeroOk,
      StaleMin,
      OpenDays,
      Active,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _OpsCfgAll : redirected to parent ZC_CA_OpsCfgAll
}

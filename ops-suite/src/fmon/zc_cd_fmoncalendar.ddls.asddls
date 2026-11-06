@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Expected files per day type'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['IfaceId', 'DayType']
define view entity ZC_CD_FmonCalendar
  as projection on ZR_CD_FmonCalendar
{
  key IfaceId,
  key DayType,
      @Consumption.hidden: true
      SingletonID,
      ExpectedCount,
      WindowFrom,
      WindowTo,
      FcalId,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _FmonCfgAll : redirected to parent ZC_CD_FmonCfgAll
}

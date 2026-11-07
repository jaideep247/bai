@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Stage deadlines (clock time)'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['IfaceId', 'Stage', 'DayType']
define view entity ZC_CD_FmonDeadline
  as projection on ZR_CD_FmonDeadline
{
  key IfaceId,
  key Stage,
  key DayType,
      @Consumption.hidden: true
      SingletonID,
      DueTime,
      Severity,
      Active,
      Description,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _FmonCfgAll : redirected to parent ZC_CD_FmonCfgAll
}

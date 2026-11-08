@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Stage SLAs (duration or deadline)'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['IfaceId', 'Stage', 'Kind', 'DayType']
define view entity ZC_CD_FmonSla
  as projection on ZR_CD_FmonSla
{
  key IfaceId,
  key Stage,
  key Kind,
  key DayType,
      @Consumption.hidden: true
      SingletonID,
      MaxMinutes,
      Basis,
      DueTime,
      Severity,
      Active,
      Description,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _FmonCfgAll : redirected to parent ZC_CD_FmonCfgAll
}

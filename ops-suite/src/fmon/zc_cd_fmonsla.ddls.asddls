@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Stage SLAs'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['IfaceId', 'Stage']
define view entity ZC_CD_FmonSla
  as projection on ZR_CD_FmonSla
{
  key IfaceId,
  key Stage,
      @Consumption.hidden: true
      SingletonID,
      MaxMinutes,
      Basis,
      Severity,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _FmonCfgAll : redirected to parent ZC_CD_FmonCfgAll
}

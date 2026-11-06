@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Return / NOC reasons'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['Reason']
define view entity ZC_CD_ReasonMap
  as projection on ZR_CD_ReasonMap
{
  key Reason,
      @Consumption.hidden: true
      SingletonID,
      FicaReason,
      IsNoc,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _EbsCfgAll : redirected to parent ZC_CD_EbsCfgAll
}

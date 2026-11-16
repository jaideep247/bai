@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Return / NOC reasons (typed ZRSN)'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['Version', 'Reason']
define view entity ZC_CD_MapReason
  as projection on ZR_CD_MapReason
{
  key Version,
  key Reason,
      @Consumption.hidden: true
      SingletonID,
      FicaReason,
      IsNoc,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _OpsCfgAll : redirected to parent ZC_CD_OpsCfgAll
}

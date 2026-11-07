@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Reconciliation clearing account sets'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['SetId']
define view entity ZC_CD_HckReconSet
  as projection on ZR_CD_HckReconSet
{
  key SetId,
      @Consumption.hidden: true
      SingletonID,
      Kind,
      Side,
      Bukrs,
      Hkont,
      Waers,
      Hbkid,
      Hktid,
      InvertBank,
      LegBank,
      LegFica,
      Tolerance,
      Description,
      Active,
      ChangedBy,
      ChangedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _HckCfgAll : redirected to parent ZC_CD_HckCfgAll
}

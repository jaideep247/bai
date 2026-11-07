@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Reconciliation bank code roles'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['SetId', 'BtcCode']
define view entity ZC_CD_HckReconBtc
  as projection on ZR_CD_HckReconBtc
{
  key SetId,
  key BtcCode,
      @Consumption.hidden: true
      SingletonID,
      Role,
      Description,
      Active,
      ChangedBy,
      ChangedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _HckCfgAll : redirected to parent ZC_CD_HckCfgAll
}

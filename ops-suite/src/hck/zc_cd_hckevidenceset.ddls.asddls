@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Evidence settings'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['SetId', 'Name']
define view entity ZC_CD_HckEvidenceSet
  as projection on ZR_CD_HckEvidenceSet
{
  key SetId,
  key Name,
      @Consumption.hidden: true
      SingletonID,
      Value,
      Description,
      Active,
      ChangedBy,
      ChangedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _HckCfgAll : redirected to parent ZC_CD_HckCfgAll
}

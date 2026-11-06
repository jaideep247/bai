@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Flow patterns (XBLNR)'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['Priority', 'Pattern']
define view entity ZC_CD_FlowPattern
  as projection on ZR_CD_FlowPattern
{
  key Priority,
  key Pattern,
      @Consumption.hidden: true
      SingletonID,
      FlowType,
      Active,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _EbsCfgAll : redirected to parent ZC_CD_EbsCfgAll
}

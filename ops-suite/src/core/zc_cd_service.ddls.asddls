@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Business services (health score)'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['Service']
define view entity ZC_CD_Service
  as projection on ZR_CD_Service
{
  key Service,
      @Consumption.hidden: true
      SingletonID,
      Label,
      Seq,
      WeightB,
      WeightE,
      WeightW,
      StalePoints,
      GreenMin,
      AmberMin,
      Active,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _OpsCfgAll : redirected to parent ZC_CD_OpsCfgAll
}

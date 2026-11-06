@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Runtime parameters'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['ParamName']
define view entity ZC_CD_OpsParam
  as projection on ZR_CD_OpsParam
{
  key ParamName,
      @Consumption.hidden: true
      SingletonID,
      ParamValue,
      Description,
      ChangedBy,
      ChangedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _OpsCfgAll : redirected to parent ZC_CD_OpsCfgAll
}

@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Account flow accounts by role'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['Area', 'FlowId', 'FlowAcct']
define view entity ZC_CA_FlowAccount
  as projection on ZR_CA_FlowAccount
{
  key Area,
  key FlowId,
  key FlowAcct,
      @Consumption.hidden: true
      SingletonID,
      Role,
      Bukrs,
      Currency,
      HkontFrom,
      HkontTo,
      LineSource,
      Seq,
      EvalClass,
      EvalCategory,
      Description,
      Active,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _OpsCfgAll : redirected to parent ZC_CA_OpsCfgAll
}

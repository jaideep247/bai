@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Mass activities and their output'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['Area', 'ActId']
define view entity ZC_CA_MassActivity
  as projection on ZR_CA_MassActivity
{
  key Area,
  key ActId,
      @Consumption.hidden: true
      SingletonID,
      Description,
      Aktyp,
      ParentProgram,
      JobPattern,
      OutputKind,
      MinOutput,
      RunLimitMin,
      Active,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _OpsCfgAll : redirected to parent ZC_CA_OpsCfgAll
}

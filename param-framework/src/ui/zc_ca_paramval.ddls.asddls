@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Parameter value'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['Area', 'Name', 'Numb']
define view entity ZC_CA_ParamVal
  as projection on ZR_CA_ParamVal
{
  key Area,
  key Name,
  key Numb,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_CA_ParamSignVH', element: 'Sign' } }]
      Sign,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_CA_ParamOptionVH', element: 'Opti' } }]
      Opti,
      Low,
      High,
      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _Definition : redirected to parent ZC_CA_ParamDef,
      _Area       : redirected to ZC_CA_ParamArea
}

@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Parameter definition'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['Area', 'Name']
@Search.searchable: true
define view entity ZC_CA_ParamDef
  as projection on ZR_CA_ParamDef
{
  key Area,
      @Search.defaultSearchElement: true
  key Name,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_CA_ParamKindVH', element: 'Kind' } }]
      Kind,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_CA_ParamValueTypeVH', element: 'ValueType' } }]
      ValueType,
      MinValue,
      MaxValue,
      DefaultValue,
      AllowedPcre,
      InterfaceName,
      Mandatory,
      DeveloperOwned,
      @Search.defaultSearchElement: true
      Description,
      Owner,
      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _Area  : redirected to parent ZC_CA_ParamArea,
      _Value : redirected to composition child ZC_CA_ParamVal
}

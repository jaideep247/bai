@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Parameter area'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: ['Area']
@Search.searchable: true
define root view entity ZC_CA_ParamArea
  provider contract transactional_query
  as projection on ZR_CA_ParamArea
{
      @Search.defaultSearchElement: true
  key Area,
      @Search.defaultSearchElement: true
      Description,
      OwnerTeam,
      ProdEditable,
      Active,
      TransportRequest,
      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,
      _Definition : redirected to composition child ZC_CA_ParamDef
}

@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Parameter area'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZR_CA_ParamArea
  as select from zca_param_area
  composition [0..*] of ZR_CA_ParamDef as _Definition
{
  key area                  as Area,
      description           as Description,
      owner_team            as OwnerTeam,
      prod_editable         as ProdEditable,
      active                as Active,
      transport_request     as TransportRequest,
      @Semantics.user.createdBy: true
      created_by            as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at            as CreatedAt,
      @Semantics.user.lastChangedBy: true
      last_changed_by       as LastChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at       as LastChangedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,
      _Definition
}

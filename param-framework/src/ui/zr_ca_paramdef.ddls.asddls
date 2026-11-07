@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Parameter definition'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CA_ParamDef
  as select from zca_param_def
  association to parent ZR_CA_ParamArea as _Area on $projection.Area = _Area.Area
  composition [0..*] of ZR_CA_ParamVal as _Value
{
  key area                  as Area,
  key name                  as Name,
      kind                  as Kind,
      value_type            as ValueType,
      min_value             as MinValue,
      max_value             as MaxValue,
      default_value         as DefaultValue,
      allowed_pcre          as AllowedPcre,
      interface_name        as InterfaceName,
      mandatory             as Mandatory,
      developer_owned       as DeveloperOwned,
      description           as Description,
      owner                 as Owner,
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
      _Area,
      _Value
}

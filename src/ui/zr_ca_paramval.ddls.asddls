@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Parameter value'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_CA_ParamVal
  as select from zca_param_val
  association to parent ZR_CA_ParamDef as _Definition on  $projection.Area = _Definition.Area
                                                        and $projection.Name = _Definition.Name
  association [1..1] to ZR_CA_ParamArea as _Area      on  $projection.Area = _Area.Area
{
  key area                  as Area,
  key name                  as Name,
  key numb                  as Numb,
      sign                  as Sign,
      opti                  as Opti,
      low                   as Low,
      high                  as High,
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
      _Definition,
      _Area
}

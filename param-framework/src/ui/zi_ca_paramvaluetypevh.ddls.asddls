@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Parameter value type (value help)'
@ObjectModel.resultSet.sizeCategory: #XS
@Metadata.ignorePropagatedAnnotations: true
// VERIFY-ADT: table function DDCDS_CUSTOMER_DOMAIN_VALUE_T (fixed values of domain ZCA_PARAM_VTYPE)
define view entity ZI_CA_ParamValueTypeVH
  as select from DDCDS_CUSTOMER_DOMAIN_VALUE_T( p_domain_name: 'ZCA_PARAM_VTYPE' )
{
      @ObjectModel.text.element: ['Description']
  key value_low as ValueType,
      @Semantics.text: true
      text      as Description
}
where
  language = $session.system_language

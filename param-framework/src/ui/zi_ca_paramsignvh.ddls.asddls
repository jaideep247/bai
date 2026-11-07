@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Range sign (value help)'
@ObjectModel.resultSet.sizeCategory: #XS
@Metadata.ignorePropagatedAnnotations: true
// VERIFY-ADT: table function DDCDS_CUSTOMER_DOMAIN_VALUE_T (fixed values of domain ZCA_PARAM_SIGN)
define view entity ZI_CA_ParamSignVH
  as select from DDCDS_CUSTOMER_DOMAIN_VALUE_T( p_domain_name: 'ZCA_PARAM_SIGN' )
{
      @ObjectModel.text.element: ['Description']
  key value_low as Sign,
      @Semantics.text: true
      text      as Description
}
where
  language = $session.system_language

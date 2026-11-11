// Artifact: zi_ca_opsreopent.ddls.asddls
// Purpose: Texts of the reason a control sign-off was reopened (new finding, severity, amount, configuration
//          version, worse status): the fixed values of domain ZCA_OPS_REOPEN in every language - translated in SE63
//          like any domain. Text association of the reason in the review app. Read-only.
// Modification log: 2026-11-11 | Initial version (explainable, versioned results).
// VERIFY-ADT: DDCDS_CUSTOMER_DOMAIN_VALUE_T released for classic ABAP on 7.58 (as ZI_CA_OpsCtlStatusT).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Reopen reason - text'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.dataCategory: #TEXT
@ObjectModel.representativeKey: 'ReopenReason'
@ObjectModel.usageType: { serviceQuality: #A, sizeCategory: #S, dataClass: #META }
define view entity ZI_CA_OpsReopenT
  as select from DDCDS_CUSTOMER_DOMAIN_VALUE_T( p_domain_name : 'ZCA_OPS_REOPEN' )
{
  key cast( value_low as zca_ops_reopen )                   as ReopenReason,
      @Semantics.language: true
  key language                                              as Language,
      @Semantics.text: true
      cast( text as abap.char( 60 ) )                       as ReopenText
}

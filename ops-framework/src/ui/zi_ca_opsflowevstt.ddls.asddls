// Artifact: zi_ca_opsflowevstt.ddls.asddls
// Purpose: Account flow reconciliation - evaluation status of an account: fixed values of domain ZCA_OPS_FLOW_EVST
//          with their texts in every language (DDCDS_CUSTOMER_DOMAIN_VALUE_T, as ZI_CA_OpsReopenT) - the text of
//          EvalStatus in the cube and the cards. Read-only.
// Modification log: 2026-11-15 | Initial version (build G: account flow reconciliation).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Account flow evaluation status - text'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.dataCategory: #TEXT
@ObjectModel.representativeKey: 'EvalStatus'
@ObjectModel.usageType: { serviceQuality: #A, sizeCategory: #S, dataClass: #META }
define view entity ZI_CA_OpsFlowEvStT
  as select from DDCDS_CUSTOMER_DOMAIN_VALUE_T( p_domain_name : 'ZCA_OPS_FLOW_EVST' )
{
  key cast( value_low as zca_ops_flow_evst )               as EvalStatus,
      @Semantics.language: true
  key language                                              as Language,
      @Semantics.text: true
      cast( text as abap.char( 60 ) )                       as EvalStatusText
}

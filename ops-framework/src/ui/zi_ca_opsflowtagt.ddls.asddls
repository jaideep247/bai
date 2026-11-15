// Artifact: zi_ca_opsflowtagt.ddls.asddls
// Purpose: Account flow reconciliation - control tag of a stage: fixed values of domain ZCA_OPS_FLOW_TAG with their
//          texts in every language (DDCDS_CUSTOMER_DOMAIN_VALUE_T, as ZI_CA_OpsReopenT) - the text of ControlStatus
//          in the cube and the cards. Read-only.
// Modification log: 2026-11-15 | Initial version (build G: account flow reconciliation).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Account flow control tag - text'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.dataCategory: #TEXT
@ObjectModel.representativeKey: 'ControlStatus'
@ObjectModel.usageType: { serviceQuality: #A, sizeCategory: #S, dataClass: #META }
define view entity ZI_CA_OpsFlowTagT
  as select from DDCDS_CUSTOMER_DOMAIN_VALUE_T( p_domain_name : 'ZCA_OPS_FLOW_TAG' )
{
  key cast( value_low as zca_ops_flow_tag )                as ControlStatus,
      @Semantics.language: true
  key language                                              as Language,
      @Semantics.text: true
      cast( text as abap.char( 60 ) )                       as ControlStatusText
}

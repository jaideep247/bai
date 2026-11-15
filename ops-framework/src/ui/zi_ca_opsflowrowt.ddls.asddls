// Artifact: zi_ca_opsflowrowt.ddls.asddls
// Purpose: Account flow reconciliation - reserved rows of the dashboard (OTHER, MOVEMENT, OPENING, CLOSING,
//          UNEXPLAINED): fixed values of domain ZCA_OPS_FLOW_ROW with their texts in every language
//          (DDCDS_CUSTOMER_DOMAIN_VALUE_T, as ZI_CA_OpsReopenT) - the text of StageId in the cube and the cards.
//          Read-only.
// Modification log: 2026-11-15 | Initial version (build G: account flow reconciliation).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Account flow reserved rows - text'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.dataCategory: #TEXT
@ObjectModel.representativeKey: 'StageId'
@ObjectModel.usageType: { serviceQuality: #A, sizeCategory: #S, dataClass: #META }
define view entity ZI_CA_OpsFlowRowT
  as select from DDCDS_CUSTOMER_DOMAIN_VALUE_T( p_domain_name : 'ZCA_OPS_FLOW_ROW' )
{
  key cast( value_low as zca_ops_flow_row )                as StageId,
      @Semantics.language: true
  key language                                              as Language,
      @Semantics.text: true
      cast( text as abap.char( 60 ) )                       as StageIdText
}

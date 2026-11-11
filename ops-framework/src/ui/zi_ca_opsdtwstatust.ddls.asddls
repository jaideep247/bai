// Artifact: zi_ca_opsdtwstatust.ddls.asddls
// Purpose: Texts of the status of a planned downtime window (Awaiting approval, Scheduled, Active, Ended): the
//          fixed values of domain ZCA_OPS_DTW_STATUS in every language - translated in SE63 like any domain,
//          never a literal of a view. Text association of the status in the downtime app. Read-only.
// Modification log: 2026-11-11 | Initial version (operations response features: planned downtime).
// VERIFY-ADT: DDCDS_CUSTOMER_DOMAIN_VALUE_T as in ZI_CA_OpsCtlStatusT (V27).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Downtime window status - text'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.dataCategory: #TEXT
@ObjectModel.representativeKey: 'WindowStatus'
@ObjectModel.usageType: { serviceQuality: #A, sizeCategory: #S, dataClass: #META }
define view entity ZI_CA_OpsDtwStatusT
  as select from DDCDS_CUSTOMER_DOMAIN_VALUE_T( p_domain_name : 'ZCA_OPS_DTW_STATUS' )
{
  key cast( value_low as zca_ops_dtw_status )               as WindowStatus,
      @Semantics.language: true
  key language                                              as Language,
      @Semantics.text: true
      cast( text as abap.char( 60 ) )                       as StatusText
}

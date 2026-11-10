// Artifact: zi_ca_opsctlstatust.ddls.asddls
// Purpose: Texts of the control status (Healthy, Watch, Action required): the fixed values of domain
//          ZCA_OPS_CTL_STATUS in every language - translated in SE63 like any domain, never a literal of a
//          view. Text association of the status in the review app and in the consumers' cards. Read-only.
// Modification log: 2026-11-10 | Initial version (control register and daily control review).
// VERIFY-ADT: DDCDS_CUSTOMER_DOMAIN_VALUE_T released for classic ABAP on 7.58; fallback: DD07T by domain
//             name and the logon language.
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Control status - text'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.dataCategory: #TEXT
@ObjectModel.representativeKey: 'ControlStatus'
@ObjectModel.usageType: { serviceQuality: #A, sizeCategory: #S, dataClass: #META }
define view entity ZI_CA_OpsCtlStatusT
  as select from DDCDS_CUSTOMER_DOMAIN_VALUE_T( p_domain_name : 'ZCA_OPS_CTL_STATUS' )
{
  key cast( value_low as zca_ops_ctl_status )               as ControlStatus,
      @Semantics.language: true
  key language                                              as Language,
      @Semantics.text: true
      cast( text as abap.char( 60 ) )                       as StatusText
}

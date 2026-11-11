// Artifact: zi_ca_paymfeeder.ddls.asddls
// Purpose: Feeder systems of a consumer's payment model (ZCA_OPS_FEEDER, framework configuration app entity
//          PaymFeeder): description, deep-link URL template (https, placeholder {REF} = the feeder's own
//          business reference; blank = no link), whether the feeder reference may be shown in full (blank =
//          masked to the last four characters, the default) and the display order. The browser of the user
//          opens a deep link; nothing in SAP calls a feeder system (read-only, no outbound call). Read-only.
// Modification log: 2026-11-11 | Initial version (payment model product layer).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment model: feeder systems'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #A, sizeCategory: #S, dataClass: #CUSTOMIZING }
define view entity ZI_CA_PaymFeeder
  as select from zca_ops_feeder
{
  key feeder                                                as Feeder,
      description                                           as FeederName,
      url_template                                          as UrlTemplate,
      ref_visible                                           as ReferenceVisible,
      seq                                                   as DisplayOrder
}

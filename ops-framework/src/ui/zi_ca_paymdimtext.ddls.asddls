// Artifact: zi_ca_paymdimtext.ddls.asddls
// Purpose: Texts and display order of the dimension values of a consumer's payment model (ZCA_OPS_PMDIM,
//          maintained in the framework configuration app ZUI_CA_OPS_CFG, entity PaymDimText): flow, source,
//          transaction, request status, payment status, method class. The generated payment model views of a
//          consumer (tools/abaptools/payment_model.py) associate their dimension values with it, so cards show
//          a business text instead of a technical code. A value without a row is shown as delivered. Read-only.
// Modification log: 2026-11-11 | Initial version (payment model product layer).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment model: dimension value texts'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.dataCategory: #TEXT
@ObjectModel.representativeKey: 'DimValue'
@ObjectModel.usageType: { serviceQuality: #A, sizeCategory: #S, dataClass: #CUSTOMIZING }
define view entity ZI_CA_PaymDimText
  as select from zca_ops_pmdim
{
      @Semantics.language: true
  key langu                                                 as Language,
  key dimension                                             as Dimension,
  key dim_value                                             as DimValue,
      @Semantics.text: true
      text                                                  as DimText,
      seq                                                   as DisplayOrder
}

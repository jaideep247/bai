// Artifact: zi_cd_ledgpaybat.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Ledger model of the ops suite - the batch keys of a payment (one row per payment, batch key and company
//          code): the link from a payment to the G/L documents of its batch keys (G/L reversals of the change timeline).
// Modification log: 2026-11-11 | Generated from the product template (ledger model).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Ledger model - batch keys of a payment'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
define view entity ZI_CD_LedgPayBat
  as select distinct from ZI_CD_LedgItem as Itm
{
  key Itm.PaymentDocument,
  key Itm.BatchKey,
  key Itm.CompanyCode
}

// Artifact: zi_cd_ledgacct.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Payment model of the ops suite - ADAPTER of the reconciled account: the contract fields of the product
//          (docs/ADDING_A_CUSTOMER_PAYMENT_MODEL.md) mapped to this landscape by the mapping spec config/payment_model/mapping.json.
//          Clearing / transit accounts of the three-way reconciliation configuration (ZCD_HCK_RCSET, active sets): one row per
//          company code, G/L account and currency (several sets of one account - kinds - collapse to one row).
// Modification log: 2026-11-11 | Generated from the mapping spec (payment model).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment model - adapter reconciled account'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
define view entity ZI_CD_LedgAcct
  as select from zcd_hck_rcset as RcSet
{
  key RcSet.bukrs as CompanyCode,
  key RcSet.hkont as GlAccount,
  key cast( RcSet.waers as abap.cuky ) as Currency,
      max( RcSet.kind ) as AccountKind,
      max( RcSet.description ) as Description
}
where
      RcSet.active = 'X'
group by
  RcSet.bukrs,
  RcSet.hkont,
  RcSet.waers

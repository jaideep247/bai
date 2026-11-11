// Artifact: zi_cd_paymreqlink.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Payment model of the ops suite - ADAPTER of the payment to request link: the contract fields of the product
//          (docs/ADDING_A_CUSTOMER_PAYMENT_MODEL.md) mapped to this landscape by the mapping spec config/payment_model/mapping.json.
//          Payment -> requests: open items cleared by the payment document (DFKKOP-AUGBL = payment document, confirmed
//          join) with their FIN number (DFKKOP-ZZ_FIN_TRANS_NUM, confirmed); one row per payment and FIN. Request ->
//          payments reads by ZZ_FIN_TRANS_NUM (index of pre-check 0.8); payment -> requests by AUGBL (index V88).
// Modification log: 2026-11-11 | Generated from the mapping spec (payment model).
// CompanyCode: VERIFY-DDIC DFKKOP-BUKRS (standard name, as config/hck_seed.md section 4)
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment model - adapter payment to request link'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
define view entity ZI_CD_PaymReqLink
  as select from dfkkop as Op
{
  key Op.augbl as PaymentDocument,
  key cast( Op.zz_fin_trans_num as abap.char( 40 ) ) as RequestReference,
      Op.bukrs as CompanyCode
}
where
      Op.augbl <> ' '
  and Op.zz_fin_trans_num <> ' '
group by
  Op.augbl,
  Op.zz_fin_trans_num,
  Op.bukrs

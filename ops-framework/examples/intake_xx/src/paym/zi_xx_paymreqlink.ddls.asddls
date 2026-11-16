// Artifact: zi_xx_paymreqlink.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Payment model of the example customer XX (intake) - ADAPTER of the payment to request link: the contract fields of the product
//          (docs/ADDING_A_CUSTOMER_PAYMENT_MODEL.md) mapped to this landscape by the mapping spec config/payment_model/mapping.json.
//          Payment -> intake: the items the payment document cleared (DFKKOP-AUGBL) with XX's payment reference
//          (custom field ZZXX_PAYREF) joined to the intake by registry link XX_ITEM_TO_INTAKE; one row per payment
//          and intake - two feeders that reused a reference give two rows (ambiguous by design, never one picked).
// Modification log: 2026-11-16 | Generated from the mapping spec (payment model).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment model - adapter payment to request link'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
define view entity ZI_XX_PaymReqLink
  as select from dfkkop as Itm
    // XX_ITEM_TO_INTAKE is ambiguous by design (LOGSYS of XX_INTAKE not covered): every candidate is a row of this n:m link
    inner join zxx_intake as Ink on  Ink.pay_ref = Itm.zzxx_payref
                                 and Ink.bukrs   = Itm.bukrs
{
  key Itm.augbl as PaymentDocument,
  key cast( Ink.intake_id as abap.char( 40 ) ) as RequestReference,
      Itm.bukrs as CompanyCode
}
where
      Itm.augbl <> ' '
group by
  Itm.augbl,
  Ink.intake_id,
  Itm.bukrs

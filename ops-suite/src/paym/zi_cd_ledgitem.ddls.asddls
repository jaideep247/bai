// Artifact: zi_cd_ledgitem.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Payment model of the ops suite - ADAPTER of the subledger item of a payment: the contract fields of the product
//          (docs/ADDING_A_CUSTOMER_PAYMENT_MODEL.md) mapped to this landscape by the mapping spec config/payment_model/mapping.json.
//          Items cleared by the payment document (DFKKOP-AUGBL = payment document, confirmed join) with the reconciliation
//          key (FIKEY) of the CLEARING document's header (DFKKKO-OPBEL = AUGBL): the clearing posts the offset of every
//          cleared item on the item's account under the clearing document's FIKEY, so per account and currency the payment's
//          FI-CA amount within the FIKEY total (DFKKSUMC) is the sum of its cleared items (VERIFY V101). The bank clearing
//          account side of the payment is reached through the bank line (FEBEP -> BSEG-XREF2 = AUGBL) and the batch key
//          level, not as an item. Transaction texts: text tables not confirmed (V103) - blank until SE11. Reads only by
//          payment document (index AUGBL, V88) or by FIKEY (DFKKKO index FIKEY, V102).
// Modification log: 2026-11-11 | Generated from the mapping spec (payment model).
// SubledgerItem: V101 VERIFY-SE11 DFKKOP-OPUPW / OPUPK / OPUPZ (item key, as the trace item read)
// CompanyCode: VERIFY-DDIC DFKKOP-BUKRS (as payment_request)
// BatchKey: V101 FIKEY of the clearing document carries the clearing's account postings (DFKKKO-FIKEY confirmed field)
// GlAccount: V101 VERIFY-SE11 DFKKOP-HKONT (reconciliation account of the item)
// Currency: V101 VERIFY-SE11 DFKKOP-WAERS
// Amount: V101 VERIFY-SE11 DFKKOP-BETRW (transaction currency, signed as DFKKSUMC-BETRW?)
// MainTransaction: VERIFY-DDIC DFKKOP-HVORG (as the HCK seeds)
// MainTransactionText: V103 main transaction text table (TFKHVOT candidate) not confirmed - blank
// SubTransaction: V101 VERIFY-SE11 DFKKOP-TVORG
// SubTransactionText: V103 sub-transaction text table (TFKTVOT candidate) not confirmed - blank
// ContractAccount: V101 VERIFY-SE11 DFKKOP-VKONT
// BusinessPartner: masked to the last four by the product view (trace rule)
// ClearingReason: AUGRD 05 = reversal (confirmed 2026-11-07)
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment model - adapter subledger item of a payment'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
define view entity ZI_CD_LedgItem
  as select from dfkkop as Op
    inner join dfkkko as Clr on Clr.opbel = Op.augbl
{
  key cast( Op.augbl as abap.char( 20 ) ) as PaymentDocument,
  key cast( Op.opbel as abap.char( 20 ) ) as SubledgerDocument,
  key cast( concat( concat( Op.opupw, Op.opupk ), Op.opupz ) as abap.char( 20 ) ) as SubledgerItem,
      Op.bukrs as CompanyCode,
      cast( Clr.fikey as abap.char( 20 ) ) as BatchKey,
      Op.hkont as GlAccount,
      Op.waers as Currency,
      @Semantics.amount.currencyCode: 'Currency'
      Op.betrw as Amount,
      Op.budat as PostingDate,
      Op.hvorg as MainTransaction,
      cast( '' as abap.char( 40 ) ) as MainTransactionText,
      Op.tvorg as SubTransaction,
      cast( '' as abap.char( 40 ) ) as SubTransactionText,
      Op.vkont as ContractAccount,
      Op.gpart as BusinessPartner,
      cast( Op.augbl as abap.char( 20 ) ) as ClearingDocument,
      Op.augdt as ClearingDate,
      Op.augrd as ClearingReason,
      cast( Op.zz_fin_trans_num as abap.char( 40 ) ) as RequestReference
}
where
      Op.augbl <> ' '

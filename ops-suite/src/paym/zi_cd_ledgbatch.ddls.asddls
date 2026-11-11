// Artifact: zi_cd_ledgbatch.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Payment model of the ops suite - ADAPTER of the subledger summary record: the contract fields of the product
//          (docs/ADDING_A_CUSTOMER_PAYMENT_MODEL.md) mapped to this landscape by the mapping spec config/payment_model/mapping.json.
//          Summary records of the payment engine G/L transfer: DFKKSUMC grouped per FIKEY, company code, account and
//          currency (confirmed path DFKKSUMC-FIKEY = DFKKKO-FIKEY = BKPF-AWKEY; G/L reference key = FIKEY, reference type
//          TRACE_GL_AWTYP FKKSU = model gl_reference_type). Posting date = the latest BUDAT of the key's records. The key
//          status (open / closed) is a field of the reconciliation key header (DFKKSUM, candidate) - V102, blank until SE11;
//          transferred / not transferred is derived from the G/L document (product view), the gap finding stays A_GL_TRANSFER.
// Modification log: 2026-11-11 | Generated from the mapping spec (payment model).
// CompanyCode: VERIFY-DDIC DFKKSUMC-BUKRS (as A_GL_TRANSFER / A_RECON_3WAY)
// GlAccount: VERIFY-DDIC DFKKSUMC-HKONT (as A_RECON_3WAY)
// Currency: VERIFY-DDIC DFKKSUMC-WAERS (as A_RECON_3WAY)
// GlReferenceKey: BKPF-AWKEY = FIKEY (confirmed path; V104 AWKEY form of a 12-character FIKEY)
// PostingDate: VERIFY-DDIC DFKKSUMC-BUDAT (as A_RECON_3WAY)
// BatchStatus: V102 reconciliation key status (open / closed) - DFKKSUM field VERIFY-SE11; blank until confirmed
// Amount: VERIFY-DDIC DFKKSUMC-BETRW signed (as A_RECON_3WAY; V101 same sign as ACDOCA-WSL)
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment model - adapter subledger summary record'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
define view entity ZI_CD_LedgBatch
  as select from dfkksumc as Sum
{
  key cast( Sum.fikey as abap.char( 20 ) ) as BatchKey,
  key Sum.bukrs as CompanyCode,
  key Sum.hkont as GlAccount,
  key Sum.waers as Currency,
      cast( Sum.fikey as abap.char( 20 ) ) as GlReferenceKey,
      max( Sum.budat ) as PostingDate,
      cast( '' as abap.char( 12 ) ) as BatchStatus,
      @Semantics.amount.currencyCode: 'Currency'
      sum( Sum.betrw ) as Amount,
      cast( count( * ) as abap.int4 ) as LineCount
}
group by
  Sum.fikey,
  Sum.bukrs,
  Sum.hkont,
  Sum.waers

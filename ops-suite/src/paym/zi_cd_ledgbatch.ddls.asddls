// Artifact: zi_cd_ledgbatch.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Payment model of the ops suite - ADAPTER of the subledger summary record: the contract fields of the product
//          (docs/ADDING_A_CUSTOMER_PAYMENT_MODEL.md) mapped to this landscape by the mapping spec config/payment_model/mapping.json.
//          Totals of the payment engine G/L transfer: DFKKSUM (totals of a reconciliation key per company code, account,
//          currency and debit / credit indicator) grouped per FIKEY, company code, account and currency (confirmed path
//          DFKKSUM-FIKEY = DFKKKO-FIKEY = BKPF-AWKEY; G/L reference key = FIKEY, reference type TRACE_GL_AWTYP FKKSU = model
//          gl_reference_type). Amount signed by SHKZG (H = credit, negative), whatever the sign of the stored BETRW. Posting
//          date = the latest BUDAT of the key's totals. The key status (open / closed) is the reconciliation key DFKKSUMC
//          (XCLOS / CLDAT, V102) - blank until its value is confirmed; transferred / not transferred is derived from the G/L
//          document (product view), the gap finding stays A_GL_TRANSFER. Fields seen on the reference system S/4HANA 2025.
// Modification log: 2026-11-11 | Generated from the mapping spec (payment model).
// CompanyCode: DFKKSUM-BUKRS (as A_GL_TRANSFER / A_RECON_3WAY)
// GlAccount: DFKKSUM-HKONT (as A_RECON_3WAY)
// Currency: DFKKSUM-WAERS (as A_RECON_3WAY)
// GlReferenceKey: BKPF-AWKEY = FIKEY (confirmed path; V104 AWKEY form of a 12-character FIKEY)
// PostingDate: DFKKSUM-BUDAT (as A_RECON_3WAY)
// BatchStatus: V102 key status: DFKKSUMC-XCLOS (closed) / CLDAT by FIKEY - value of XCLOS to confirm; blank
// Amount: DFKKSUM-BETRW signed by SHKZG (as A_RECON_3WAY; V101 same sign as ACDOCA-WSL; VERIFY-ADT CURR * -1)
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment model - adapter subledger summary record'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
define view entity ZI_CD_LedgBatch
  as select from dfkksum as Sum
{
  key cast( Sum.fikey as abap.char( 20 ) ) as BatchKey,
  key Sum.bukrs as CompanyCode,
  key Sum.hkont as GlAccount,
  key Sum.waers as Currency,
      cast( Sum.fikey as abap.char( 20 ) ) as GlReferenceKey,
      max( Sum.budat ) as PostingDate,
      cast( '' as abap.char( 12 ) ) as BatchStatus,
      @Semantics.amount.currencyCode: 'Currency'
      sum( case when Sum.shkzg = 'H' then abs( Sum.betrw ) * -1 else abs( Sum.betrw ) end ) as Amount,
      cast( count( * ) as abap.int4 ) as LineCount
}
group by
  Sum.fikey,
  Sum.bukrs,
  Sum.hkont,
  Sum.waers

// Artifact: zr_cd_paymrequest.ddls.asddls (generated - tools/abaptools/payment_model.py; never edit, regenerate)
// Purpose: Payment model of the ops suite - one payment request (object page): the accepted attempt of the
//          request (adapter ZI_CD_PaymReqFact - which attempt counts is the consumer's rule in the mapping spec),
//          its feeder system (ZI_CA_PaymFeeder) with the feeder's own reference - MASKED to the last four
//          characters unless the feeder row marks it not sensitive - and the deep link into the feeder's UI
//          (URL template with {REF}; only for a visible reference; opened by the browser, never called by SAP);
//          navigation to all attempts, to the timeline feeder -> middleware -> request -> payment -> status sent
//          back, and to the payments of the request (1:n). Read-only.
// Modification log: 2026-11-11 | Generated from the product template (payment model).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment model - payment request'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
define root view entity ZR_CD_PaymRequest
  as select from    ZI_CD_PaymReqFact as Req
    left outer join ZI_CA_PaymFeeder     as Fdr  on Fdr.Feeder = Req.Source
    left outer join ZI_CA_PaymDimText    as TxnT on  TxnT.Language  = $session.system_language
                                                 and TxnT.Dimension = 'TRANSACTION'
                                                 and TxnT.DimValue  = Req.TransactionType
  association [0..*] to ZR_CD_PaymReqLink as _Payments on $projection.RequestReference = _Payments.RequestReference
  association [0..*] to ZR_CD_ReqChange   as _Changes  on $projection.RequestReference = _Changes.RequestReference
{
  key Req.RequestReference,
      _Payments,
      _Changes,
      Req.BusinessDate,
      Req.ReceivedAt,
      Req.CompanyCode,
      cast( 'CD_OPS' as abap.char( 16 ) )                 as OpsArea,
      Req.Source,
      Fdr.FeederName,
      Req.TransactionType,
      TxnT.DimText                                          as TransactionText,
      Req.RequestStatus,
      Req.ProcessingStatus,
      cast( case when Fdr.ReferenceVisible = 'X' then Req.FeederReference
                 else concat( '****', right( Req.FeederReference, 4 ) ) end as abap.char( 40 ) ) as FeederReference,
      cast( case when Fdr.ReferenceVisible = 'X' and Fdr.UrlTemplate <> ''
                 then replace( Fdr.UrlTemplate, '{REF}', Req.FeederReference )
                 else '' end as abap.char( 255 ) )          as FeederUrl,
      Req.Currency,
      @Semantics.amount.currencyCode: 'Currency'
      Req.Amount
}

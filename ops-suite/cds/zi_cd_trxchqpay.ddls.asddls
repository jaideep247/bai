// Artifact: zi_cd_trxchqpay.ddls.asddls
// Purpose: IRIS cheque status (ZCD_CHECK_HIST via ZI_CD_TrxChqStat) per payment document: a cheque
//          of the payment (DFKKCR-DOC1R = AUGBL, confirmed) ever failed / rejected (3 / 4). Existence
//          flags only (any cheque of the payment), no value of one cheque mixed with another. The
//          request funnel shows REJECTED from it only while the payment has no canonical outcome.
//          ADT only (cds/). Read-only.
// Modification log: 2026-11-07 | Initial version (request funnel joined by payment document).
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Cheque status flags per payment document'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #M, dataClass: #TRANSACTIONAL }
@VDM.viewType: #COMPOSITE
define view entity ZI_CD_TrxChqPay
  as select from dfkkcr           as Chq
    inner join   ZI_CD_TrxChqStat as Stat on Stat.ChequeNo = Chq.ztnum
{
  key Chq.doc1r                                             as PaymentDocument,
      cast( max( Stat.IsFailed ) as abap.int1 )             as IsFailed
}
where Chq.doc1r <> ' '
group by
  Chq.doc1r

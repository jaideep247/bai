// Artifact: zr_cd_trxretnoc.ddls.asddls
// Purpose: Returns and NOCs by reason of the transactions of the 45-day evidence window (transactions
//          dashboard): one row per open item and lot item, kind RETURN (DFKKRP, reason RLGRD) or
//          NOC (DFKKNRP, reason FLGRD), with FIN, company code, payment method, direction, amount.
//          Chart "returns / NOC by reason"; drill-down from the transaction. Read-only.
// Modification log: 2026-11-06 | Initial version (transactions dashboard).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Transactions dashboard - returns / NOC'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #M, dataClass: #MIXED }
define root view entity ZR_CD_TrxRetNoc
  as select from ZI_CD_TrxRetNocU
{
  key DocumentNo,
  key RepetitionItem,
  key ItemNo,
  key SubItem,
  key LotKind,
  key LotItemKey,
      cast( 'CD_OPS' as abap.char( 16 ) )                      as PaymentEngineArea,
      Reason,
      LotStatus,
      FinId,
      CompanyCode,
      PostingDate,
      PaymentMethod,
      Direction,
      ClearingDoc,
      Currency,
      @Semantics.amount.currencyCode: 'Currency'
      Amount,
      cast( 1 as abap.int4 )                                as LotItemCount,
      cast( case LotKind when 'RETURN' then 1 else 0 end as abap.int4 ) as ReturnCount,
      cast( case LotKind when 'NOC' then 1 else 0 end as abap.int4 )    as NocCount
}

// Artifact: zc_cd_trxretnoc.ddls.asddls
// Purpose: Consumption view of returns (DFKKRP-RLGRD) and NOCs (DFKKNRP-FLGRD) of the
//          transactions (service ZUI_CD_TRX_DASH): by reason, drill-down to the lot item.
//          Read access: DCL ZC_CD_TRXDASH (ZCD_OPS, ZCD_PE_AREA = CORE and BUKRS, ACTVT 03). Read-only.
// Modification log: 2026-11-06 | Initial version (transactions dashboard).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Transactions dashboard - returns / NOC'
@Metadata.allowExtensions: true
define root view entity ZC_CD_TrxRetNoc
  provider contract transactional_query
  as projection on ZR_CD_TrxRetNoc
{
  key DocumentNo,
  key RepetitionItem,
  key ItemNo,
  key SubItem,
  key LotKind,
  key LotItemKey,
      PaymentEngineArea,
      Reason,
      LotStatus,
      FinId,
      CompanyCode,
      PostingDate,
      PaymentMethod,
      Direction,
      ClearingDoc,
      Currency,
      Amount,
      @Aggregation.default: #SUM
      LotItemCount,
      @Aggregation.default: #SUM
      ReturnCount,
      @Aggregation.default: #SUM
      NocCount
}

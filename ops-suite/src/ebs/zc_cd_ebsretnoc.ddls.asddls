// Artifact: zc_cd_ebsretnoc.ddls.asddls
// Purpose: Consumption view of returns (DFKKRP-RLGRD) and NOCs (DFKKNRP-FLGRD) behind the
//          bank statement lines (service ZUI_CD_EBS_DASH): by reason, drill-down to the lot item.
//          Read access: DCL ZC_CD_EBSDASH (ZCD_OPS, ZCD_PE_AREA = EBS, ACTVT 03). Read-only.
// Modification log: 2026-11-06 | Initial version (EBS validation dashboard).
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'EBS validation dashboard - returns / NOC'
@Metadata.allowExtensions: true
define root view entity ZC_CD_EbsRetNoc
  provider contract transactional_query
  as projection on ZR_CD_EbsRetNoc
{
  key Kukey,
  key Esnum,
  key LotKind,
  key LotItemKey,
      PaymentEngineArea,
      Reason,
      LotStatus,
      LineObjectKey,
      CompanyCode,
      HouseBank,
      StatementDate,
      BookingDate,
      BaiCode,
      BankReference,
      Currency,
      Amount,
      @Aggregation.default: #SUM
      LotItemCount,
      @Aggregation.default: #SUM
      ReturnCount,
      @Aggregation.default: #SUM
      NocCount
}

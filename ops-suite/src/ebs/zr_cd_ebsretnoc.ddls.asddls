// Artifact: zr_cd_ebsretnoc.ddls.asddls
// Purpose: Returns and NOCs by reason behind the bank statement lines of the last 31 days (EBS
//          validation dashboard): one row per line and lot item, kind RETURN (DFKKRP, reason
//          RLGRD) or NOC (DFKKNRP, reason FLGRD), lot item key, house bank, BAI code, amount.
//          Drill-down from the line; chart "returns / NOC by reason". Read-only.
// Modification log: 2026-11-06 | Initial version (EBS validation dashboard).
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'EBS validation dashboard - returns / NOC'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #C, sizeCategory: #M, dataClass: #MIXED }
define root view entity ZR_CD_EbsRetNoc
  as select from ZI_CD_EbsRetNocU
{
  key Kukey,
  key Esnum,
  key LotKind,
  key LotItemKey,
      cast( 'EBS' as abap.char( 4 ) )                       as PaymentEngineArea,
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
      @Semantics.amount.currencyCode: 'Currency'
      Amount,
      cast( 1 as abap.int4 )                                as LotItemCount,
      cast( case LotKind when 'RETURN' then 1 else 0 end as abap.int4 ) as ReturnCount,
      cast( case LotKind when 'NOC' then 1 else 0 end as abap.int4 )    as NocCount
}

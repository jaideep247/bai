// Artifact: zi_cd_trxchqstat.ddls.asddls
// Purpose: Cheque status from IRIS via PRISM (ZCD_CHECK_HIST) per cheque number: ever returned
//          (ZECT_STATUS 9, terminal), ever failed / rejected (3 / 4, terminal), ever mailed (10;
//          10 -> 9 is allowed, PRISM translates IRIS "confirmed" to mailed). Flags instead of a
//          "highest status" because the status is not numeric-ordered as text ('10' < '9').
//          ADT only (cds/). VERIFY-SE11 placeholders - replace before activation:
//            zz_check_no     -> cheque number field (= DFKKCR-ZTNUM)
//            zz_check_status -> status field with domain ZECT_STATUS (confirmed domain)
//          Read-only.
// Modification log: 2026-11-06 | Initial version (transactions dashboard, request side).
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Cheque status per cheque (IRIS)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #M, dataClass: #TRANSACTIONAL }
@VDM.viewType: #COMPOSITE
define view entity ZI_CD_TrxChqStat
  as select from zcd_check_hist
{
  // VERIFY-SE11: cheque number field
  key cast( zz_check_no as abap.char( 13 ) )                as ChequeNo,
      cast( count( * ) as abap.int4 )                       as StatusRowCount,
      cast( max( case zz_check_status when '9' then 1 else 0 end ) as abap.int1 ) as IsReturned,
      cast( max( case when zz_check_status = '3' or zz_check_status = '4' then 1 else 0 end ) as abap.int1 ) as IsFailed,
      cast( max( case zz_check_status when '10' then 1 else 0 end ) as abap.int1 ) as IsMailed
}
group by
  zz_check_no

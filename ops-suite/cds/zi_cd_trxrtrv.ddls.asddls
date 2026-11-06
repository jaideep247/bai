// Artifact: zi_cd_trxrtrv.ddls.asddls
// Purpose: ACH manual retrieval log (ZCD_ACH_RTRV_LOG) per payment document AUGBL (confirmed key,
//          as ZCL_CD_EBS_SAP_DAO=>GET_RETRIEVALS): retrieval rows. ADT only (cds/).
//          VERIFY-SE11 placeholder - the status field has three candidate names in the legacy code
//          (ZZ_RTRVL_STATUS, ZZ_RTRV_STATUS, ZZRETRIEVAL_STATUS; parity C4, parameter
//          EBS_RTRV_STATUS_FIELD): keep the one SE11 shows. Read-only.
// Modification log: 2026-11-06 | Initial version (transactions dashboard, request side).
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'ACH retrieval per payment document'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #M, dataClass: #TRANSACTIONAL }
@VDM.viewType: #COMPOSITE
define view entity ZI_CD_TrxRtrv
  as select from zcd_ach_rtrv_log
{
  key augbl                                                 as PaymentDocument,
      cast( count( * ) as abap.int4 )                       as RetrievalCount,
      // VERIFY-SE11: one of ZZ_RTRVL_STATUS / ZZ_RTRV_STATUS / ZZRETRIEVAL_STATUS
      max( zz_rtrvl_status )                                as RetrievalStatus
}
where augbl <> ' '
group by
  augbl

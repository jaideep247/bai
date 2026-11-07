// Artifact: zi_cd_trxreqlog.ddls.asddls
// Purpose: Basic view of the payment request log ZCD_PAYM_REQ_LOG (requests from PRISM) for the
//          request side of the transactions dashboard (docs/Dashboard_Transactions.md section 4):
//          one row per request attempt - every attempt, no date window: the SUCCESS row rule
//          (ZI_CD_TrxRequest) looks at all attempts of a request first, the date window is applied
//          to the request afterwards (ZI_CD_TrxReqWin). Confirmed fields: SOURCE, COUNTER,
//          ZZ_STATUS (SUCCESS = processed). The member number ZZ_MEMBER_NO is NOT selected.
//          ADT only (cds/, outside the abapGit pull): activate after SE11 confirmation.
//          VERIFY-SE11 placeholders - replace before activation:
//            zz_fin_trans_num  -> the FIN number field of ZCD_PAYM_REQ_LOG (= DFKKOP-ZZ_FIN_TRANS_NUM)
//            zz_created_on     -> the request date field (DATS)
// Modification log: 2026-11-06 | Initial version (transactions dashboard, request side).
//                   2026-11-07 | Review defect: the 30-day window on zz_created_on was applied before the
//                   SUCCESS rule (an earlier SUCCESS attempt was dropped and the request shown ERRORED) -
//                   window removed here, applied to the request after the rule (ZI_CD_TrxReqWin).
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Payment request attempt (basic)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: { serviceQuality: #B, sizeCategory: #L, dataClass: #TRANSACTIONAL }
@VDM.viewType: #BASIC
define view entity ZI_CD_TrxReqLog
  as select from zcd_paym_req_log
{
  // VERIFY-SE11: FIN number field
  key zz_fin_trans_num                                      as FinId,
  key source                                                as SourceSystem,
  key counter                                               as AttemptCounter,
      zz_status                                             as RequestStatus,
      // VERIFY-SE11: request date field
      zz_created_on                                         as RequestDate,
      // SUCCESS row rule: processed when ANY attempt has SUCCESS - never the highest COUNTER
      case when zz_status = 'SUCCESS'
           then cast( 'X' as abap_boolean )
           else cast( ' ' as abap_boolean ) end             as IsSuccess,
      // VERIFY-SE11: failure values of ZZ_STATUS (config/hck_seed.md C_PRQ_NO_SPE "FAIL=")
      case when zz_status = 'FAILED' or zz_status = 'ERROR' or zz_status = 'REJECTED'
           then cast( 'X' as abap_boolean )
           else cast( ' ' as abap_boolean ) end             as IsError,
      case when zz_status = 'CANCELLED'
           then cast( 'X' as abap_boolean )
           else cast( ' ' as abap_boolean ) end             as IsCancelled
}

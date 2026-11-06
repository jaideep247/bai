// Artifact: zi_cd_trxreqlog.ddls.asddls
// Purpose: Basic view of the payment request log ZCD_PAYM_REQ_LOG (requests from PRISM) for the
//          request side of the transactions dashboard (docs/Dashboard_Transactions.md section 5):
//          one row per request attempt of the last 31 days. Confirmed fields: SOURCE, COUNTER,
//          ZZ_STATUS (SUCCESS = processed). The member number ZZ_MEMBER_NO is NOT selected.
//          ADT only (cds/, outside the abapGit pull): activate after SE11 confirmation.
//          VERIFY-SE11 placeholders - replace before activation:
//            zz_fin_trans_num  -> the FIN number field of ZCD_PAYM_REQ_LOG (= DFKKOP-ZZ_FIN_TRANS_NUM)
//            zz_created_on     -> the request date field (DATS)
// Modification log: 2026-11-06 | Initial version (transactions dashboard, request side).
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
// VERIFY-SE11: request date field
where zz_created_on >= dats_add_days( $session.system_date, -30, 'INITIAL' )
